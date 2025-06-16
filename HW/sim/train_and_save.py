#!/usr/bin/env python

import sys
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import numpy as np
import os
import random
import torch.ao.quantization as quantization
from torch.ao.quantization.observer import MinMaxObserver

MNIST_PATH = "../design/ref_cpp/mnist_dataset/"
NUM_EPOCHS = 10

if len(sys.argv) != 2:
    print("Usage: ./train_and_save.py <rand_seed>")
    sys.exit(1)
seed = int(sys.argv[1])

torch.manual_seed(seed)
np.random.seed(seed)
random.seed(seed)
torch.backends.cudnn.deterministic = True
torch.backends.cudnn.benchmark = False

transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))
])

class LeNet5(nn.Module):
    def __init__(self):
        super(LeNet5, self).__init__()
        self.quant = quantization.QuantStub()
        self.conv1 = nn.Conv2d(1, 6, 5, padding=2)
        self.pool = nn.MaxPool2d(2, 2)
        self.conv2 = nn.Conv2d(6, 16, 5)
        self.fc1 = nn.Linear(16 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, 10)
        self.dequant = quantization.DeQuantStub()

    def forward(self, x):
        x = self.quant(x)
        x = self.pool(torch.relu(self.conv1(x)))
        x = self.pool(torch.relu(self.conv2(x)))
        x = x.reshape(-1, 16 * 5 * 5)
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        x = self.fc3(x)
        x = self.dequant(x)
        return x

class PowerOfTwoObserver(MinMaxObserver):
    def __init__(self, dtype=torch.qint8, qscheme=torch.per_tensor_symmetric, reduce_range=False, **kwargs):
        super(PowerOfTwoObserver, self).__init__(dtype=dtype, qscheme=qscheme, reduce_range=reduce_range)
    
    def calculate_qparams(self):
        scale, _ = super().calculate_qparams()
        if scale > 0:
            exponent = torch.ceil(torch.log2(scale))
            scale = torch.pow(2, exponent)
        zero_point = torch.tensor(0, dtype=torch.int32)
        return scale, zero_point

def quantize_bias(bias, input_scale, weight_scale, bit_width=16):
    bias_scale = input_scale * weight_scale
    qmin = -(2**(bit_width - 1))
    qmax = 2**(bit_width - 1) - 1
    bias_quant = torch.round(bias / bias_scale).to(torch.int16)
    bias_quant = torch.clamp(bias_quant, qmin, qmax)
    return bias_quant, bias_scale

def save_quantized_param(key, quantized_weight, MNIST_PATH):
    param_int = quantized_weight.int_repr().detach().cpu().numpy().astype(np.int8)
    weight_scale = quantized_weight.q_scale()
    
    txt_filename = os.path.join(MNIST_PATH, f"{key.replace('.', '_')}_quantized.txt")
    with open(txt_filename, 'w') as f:
        shape = param_int.shape
        if len(shape) == 4:  # Conv 레이어
            for och in range(shape[0]):
                for ich in range(shape[1]):
                    for ky in range(shape[2]):
                        for kx in range(shape[3]):
                            int_val = param_int[och, ich, ky, kx]
                            real_val = int_val * weight_scale
                            hex_val = f"0x{int_val & 0xff:02x}"
                            indices = f"({och:02d}, {ich:02d}, {ky:02d}, {kx:02d})"
                            f.write(f"{indices} {hex_val}, {real_val}\n")
        elif len(shape) == 2:  # FC 레이어
            for och in range(shape[0]):
                for ich in range(shape[1]):
                    int_val = param_int[och, ich]
                    real_val = int_val * weight_scale
                    hex_val = f"0x{int_val & 0xff:02x}"
                    indices = f"({och:02d}, {ich:02d})"
                    f.write(f"{indices} {hex_val}, {real_val}\n")

def save_quantized_bias(key, bias_quant_np, bias_scale, MNIST_PATH):
    txt_filename = os.path.join(MNIST_PATH, f"{key.replace('.', '_')}_quantized.txt")
    with open(txt_filename, 'w') as f:
        for och in range(bias_quant_np.shape[0]):
            int_val = bias_quant_np[och]
            hex_val = f"0x{int_val & 0xffff:04x}"
            real_val = int_val * bias_scale
            indices = f"({och:02d})"
            f.write(f"{indices} {hex_val}, {real_val}\n")

def save_weights_and_biases(quantized_model, qat_model, MNIST_PATH):
    state_dict = quantized_model.state_dict()
    input_scale = quantized_model.quant.scale.item()
    layer_scales = {'input': input_scale}

    # conv1 레이어
    key = 'conv1'
    weight_key = f'{key}.weight'
    bias_key = f'{key}.bias'
    quantized_weight = state_dict[weight_key]
    save_quantized_param(weight_key, quantized_weight, MNIST_PATH)
    
    weight_scale = quantized_weight.q_scale()
    weight_scale_inv = 1.0 / weight_scale
    with open(os.path.join(MNIST_PATH, f"{weight_key.replace('.', '_')}_scale_inv.txt"), 'w') as f:
        f.write(f"{weight_scale_inv}\n")
    
    output_scale = get_activation_scale(qat_model, key)
    if output_scale is not None:
        output_scale_inv = 1.0 / output_scale
        with open(os.path.join(MNIST_PATH, f"{key}_output_scale_inv.txt"), 'w') as f:
            f.write(f"{output_scale_inv}\n")
        M_INV = output_scale / (input_scale * weight_scale)
        with open(os.path.join(MNIST_PATH, f"{key}_M_INV.txt"), 'w') as f:
            f.write(f"{M_INV}\n")
    layer_scales[key] = output_scale or weight_scale

    if bias_key in state_dict:
        bias_value = state_dict[bias_key]
        bias_float = bias_value.detach().cpu()
        prev_scale = layer_scales['input']
        bias_quant, bias_scale = quantize_bias(bias_float, prev_scale, weight_scale, bit_width=16)
        bias_quant_np = bias_quant.numpy().astype(np.int16)
        bias_scale_inv = 1.0 / bias_scale
        with open(os.path.join(MNIST_PATH, f"{bias_key.replace('.', '_')}_scale_inv.txt"), 'w') as f:
            f.write(f"{bias_scale_inv}\n")
        save_quantized_bias(bias_key, bias_quant_np, bias_scale, MNIST_PATH)
    print(f"Saved files for {key}: weight, bias, output scale inv, M_INV")

    # conv2 레이어
    key = 'conv2'
    weight_key = f'{key}.weight'
    bias_key = f'{key}.bias'
    quantized_weight = state_dict[weight_key]
    save_quantized_param(weight_key, quantized_weight, MNIST_PATH)
    
    weight_scale = quantized_weight.q_scale()
    weight_scale_inv = 1.0 / weight_scale
    with open(os.path.join(MNIST_PATH, f"{weight_key.replace('.', '_')}_scale_inv.txt"), 'w') as f:
        f.write(f"{weight_scale_inv}\n")
    
    output_scale = get_activation_scale(qat_model, key)
    if output_scale is not None:
        output_scale_inv = 1.0 / output_scale
        with open(os.path.join(MNIST_PATH, f"{key}_output_scale_inv.txt"), 'w') as f:
            f.write(f"{output_scale_inv}\n")
        input_scale = layer_scales['conv1']
        M_INV = output_scale / (input_scale * weight_scale)
        with open(os.path.join(MNIST_PATH, f"{key}_M_INV.txt"), 'w') as f:
            f.write(f"{M_INV}\n")
    layer_scales[key] = output_scale or weight_scale

    if bias_key in state_dict:
        bias_value = state_dict[bias_key]
        bias_float = bias_value.detach().cpu()
        prev_scale = layer_scales['conv1']
        bias_quant, bias_scale = quantize_bias(bias_float, prev_scale, weight_scale, bit_width=16)
        bias_quant_np = bias_quant.numpy().astype(np.int16)
        bias_scale_inv = 1.0 / bias_scale
        with open(os.path.join(MNIST_PATH, f"{bias_key.replace('.', '_')}_scale_inv.txt"), 'w') as f:
            f.write(f"{bias_scale_inv}\n")
        save_quantized_bias(bias_key, bias_quant_np, bias_scale, MNIST_PATH)
    print(f"Saved files for {key}: weight, bias, output scale inv, M_INV")

    # fc1, fc2, fc3 레이어
    for key in ['fc1', 'fc2', 'fc3']:
        packed_params_key = f'{key}._packed_params._packed_params'
        if packed_params_key in state_dict:
            quantized_weight, bias = state_dict[packed_params_key]
            weight_key = f'{key}.weight'
            bias_key = f'{key}.bias'
            save_quantized_param(weight_key, quantized_weight, MNIST_PATH)
            
            weight_scale = quantized_weight.q_scale()
            weight_scale_inv = 1.0 / weight_scale
            with open(os.path.join(MNIST_PATH, f"{weight_key.replace('.', '_')}_scale_inv.txt"), 'w') as f:
                f.write(f"{weight_scale_inv}\n")
            
            output_scale = get_activation_scale(qat_model, key)
            if output_scale is not None:
                output_scale_inv = 1.0 / output_scale
                with open(os.path.join(MNIST_PATH, f"{key}_output_scale_inv.txt"), 'w') as f:
                    f.write(f"{output_scale_inv}\n")
                input_scale = layer_scales['conv2' if key == 'fc1' else ('fc1' if key == 'fc2' else 'fc2')]
                M_INV = output_scale / (input_scale * weight_scale)
                with open(os.path.join(MNIST_PATH, f"{key}_M_INV.txt"), 'w') as f:
                    f.write(f"{M_INV}\n")
            layer_scales[key] = output_scale or weight_scale

            if bias is not None:
                bias_float = bias.detach().cpu()
                prev_scale = layer_scales['conv2' if key == 'fc1' else ('fc1' if key == 'fc2' else 'fc2')]
                bias_quant, bias_scale = quantize_bias(bias_float, prev_scale, weight_scale, bit_width=16)
                bias_quant_np = bias_quant.numpy().astype(np.int16)
                bias_scale_inv = 1.0 / bias_scale
                with open(os.path.join(MNIST_PATH, f"{bias_key.replace('.', '_')}_scale_inv.txt"), 'w') as f:
                    f.write(f"{bias_scale_inv}\n")
                save_quantized_bias(bias_key, bias_quant_np, bias_scale, MNIST_PATH)
        print(f"Saved files for {key}: weight, bias, output scale inv, M_INV")

def save_quantization_params(quantized_model, qat_model, MNIST_PATH):
    input_scale = quantized_model.quant.scale.item()
    input_scale_inv = 1.0 / input_scale
    with open(os.path.join(MNIST_PATH, "input_scale_inv.txt"), 'w') as f:
        f.write(f"{input_scale_inv}\n")
    
    output_scale = get_activation_scale(qat_model, 'fc3')
    if output_scale is not None:
        output_scale_inv = 1.0 / output_scale
        with open(os.path.join(MNIST_PATH, "fc3_output_scale_inv.txt"), 'w') as f:
            f.write(f"{output_scale_inv}\n")
    else:
        raise ValueError("Failed to retrieve output scale for fc3")

def get_activation_scale(model, layer_name):
    layer = getattr(model, layer_name)
    if isinstance(layer, (nn.qat.Conv2d, nn.qat.Linear)):
        observer = layer.activation_post_process
        scale, _ = observer.calculate_qparams()
        return scale.item()
    return None

def train_model(model, train_loader, criterion, optimizer, num_epochs):
    model.train()
    for epoch in range(num_epochs):
        running_loss = 0.0
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to('cuda'), target.to('cuda')
            optimizer.zero_grad()
            output = model(data)
            loss = criterion(output, target)
            loss.backward()
            optimizer.step()
            running_loss += loss.item()
        print(f'Epoch {epoch+1}/{num_epochs}, Loss: {running_loss / len(train_loader):.4f}')

def test_model(model, test_loader):
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to('cuda'), target.to('cuda')
            output = model(data)
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()
            total += data.shape[0]
    accuracy = correct / total
    print(f"Test Accuracy after QAT: {accuracy * 100:.2f}%")
    return accuracy

if __name__ == "__main__":
    train_dataset = datasets.MNIST(root=MNIST_PATH, train=True, download=True, transform=transform)
    train_loader = DataLoader(dataset=train_dataset, batch_size=64, shuffle=True)
    
    test_dataset = datasets.MNIST(root=MNIST_PATH, train=False, download=True, transform=transform)
    test_loader = DataLoader(dataset=test_dataset, batch_size=64, shuffle=False)
    
    model = LeNet5().to('cuda')
    model.train()
    
    qconfig = quantization.QConfig(
        activation=PowerOfTwoObserver.with_args(dtype=torch.qint8, qscheme=torch.per_tensor_symmetric),
        weight=PowerOfTwoObserver.with_args(dtype=torch.qint8, qscheme=torch.per_tensor_symmetric)
    )
    model.qconfig = qconfig
    quantization.prepare_qat(model, inplace=True)
    
    criterion = nn.CrossEntropyLoss().to('cuda')
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    
    train_model(model, train_loader, criterion, optimizer, num_epochs=NUM_EPOCHS)
    test_model(model, test_loader)
    
    model.eval()
    model.to('cpu')
    quantized_model = quantization.convert(model, inplace=False)
    
    save_weights_and_biases(quantized_model, model, MNIST_PATH)
    save_quantization_params(quantized_model, model, MNIST_PATH)