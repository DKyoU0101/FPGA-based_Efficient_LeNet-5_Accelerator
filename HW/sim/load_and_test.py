#!/usr/bin/env python

import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import datasets, transforms
from torch.utils.data import DataLoader, Subset
import os
import re

NUM_TEST_IMAGES = 10
MNIST_PATH = "../design/ref_cpp/mnist_dataset/"

# 레이어 설정
layers = {
    'conv1': {'weight_shape': (6, 1, 5, 5), 'bias_shape': (6,)},
    'conv2': {'weight_shape': (16, 6, 5, 5), 'bias_shape': (16,)},
    'fc1': {'weight_shape': (120, 400), 'bias_shape': (120,)},
    'fc2': {'weight_shape': (84, 120), 'bias_shape': (84,)},
    'fc3': {'weight_shape': (10, 84), 'bias_shape': (10,)}
}

def load_quantized_tensor(file_path, shape, dtype):
    with open(file_path, 'r') as f:
        lines = f.readlines()
        values = []
        for line in lines:
            match = re.search(r'0x[0-9a-fA-F]+', line)
            if match:
                hex_val = match.group()
                int_val = int(hex_val[2:], 16)
                if dtype == torch.int8 and int_val > 127:
                    int_val -= 256
                elif dtype == torch.int16 and int_val > 32767:
                    int_val -= 65536
                values.append(int_val)
            else:
                print(f"Warning: No hex value found in line: {line.strip()}")
        expected_size = torch.prod(torch.tensor(shape))
        if len(values) != expected_size:
            raise ValueError(f"Expected {expected_size} values, but got {len(values)}")
        tensor = torch.tensor(values, dtype=dtype).reshape(shape)
        return tensor

def load_scale(file_path):
    with open(file_path, 'r') as f:
        load_scale_inv = float(f.read().strip())
        return 1 / load_scale_inv

def fake_quant(x, scale, scale_inv, zero_point=0):
    qmin = -128
    qmax = 127
    x_q = torch.round(x * scale_inv + zero_point)
    x_q = torch.clamp(x_q, qmin, qmax)
    x_dq = (x_q - zero_point) * scale
    return x_q, x_dq

def save_file(x_q, x_dq, file_path, width, mode='w'):
    with open(file_path, mode) as f:
        for idx, (q_val, dq_val) in enumerate(zip(x_q.flatten(), x_dq.flatten())):
            if q_val < 0:
                hex_val = f"0x{(256 + int(q_val)):02x}"
            else:
                hex_val = f"0x{int(q_val):02x}"
            c = idx // (width * width)
            y = (idx % (width * width)) // width
            x = idx % width
            f.write(f"({c:02d}, {y:02d}, {x:02d}) {hex_val}, {dq_val:.6f}\n")

def inference(data, params, input_scale, input_scale_inv):
    x = data
    x_q, x_dq = fake_quant(x, input_scale, input_scale_inv, zero_point=0)
    
    mean = 0.1307
    std = 0.3081
    background_value = (0 - mean) / std
    
    x_dq_padded = F.pad(x_dq, (2, 2, 2, 2), mode='constant', value=background_value)
    x_q_padded, x_dq_padded = fake_quant(x_dq_padded, input_scale, input_scale_inv, zero_point=0)
    if NUM_TEST_IMAGES <= 100:
        save_file(x_q_padded[0], x_dq_padded[0], os.path.join(MNIST_PATH, "input_y_q_padd.txt"), 32, mode='a')
    
    if NUM_TEST_IMAGES == 1:
        save_file(x_q_padded[0], x_dq_padded[0], os.path.join(MNIST_PATH, "input_y_q_padd.txt"), 32, mode='w')
    
    # Conv1
    w_real = params['conv1']['w_real']
    b_real = params['conv1']['b_real']
    y = F.conv2d(x_dq, w_real, bias=b_real, padding=2)
    y = F.relu(y)
    if NUM_TEST_IMAGES == 1:
        y_q, y_dq = fake_quant(y, params['conv1']['output_scale'], params['conv1']['output_scale_inv'], zero_point=0)
        save_file(y_q[0], y[0], os.path.join(MNIST_PATH, "conv1_y_post_activation.txt"), 28)
    
    y = F.max_pool2d(y, 2)
    y_q, y_dq = fake_quant(y, params['conv1']['output_scale'], params['conv1']['output_scale_inv'], zero_point=0)
    if NUM_TEST_IMAGES == 1:
        save_file(y_q[0], y_dq[0], os.path.join(MNIST_PATH, "conv1_y_q.txt"), 14)
    
    # Conv2
    w_real = params['conv2']['w_real']
    b_real = params['conv2']['b_real']
    y = F.conv2d(y_dq, w_real, bias=b_real)
    y = F.relu(y)
    if NUM_TEST_IMAGES == 1:
        y_q, y_dq = fake_quant(y, params['conv2']['output_scale'], params['conv2']['output_scale_inv'], zero_point=0)
        save_file(y_q[0], y[0], os.path.join(MNIST_PATH, "conv2_y_post_activation.txt"), 10)
    
    y = F.max_pool2d(y, 2)
    y_q, y_dq = fake_quant(y, params['conv2']['output_scale'], params['conv2']['output_scale_inv'], zero_point=0)
    if NUM_TEST_IMAGES == 1:
        save_file(y_q[0], y_dq[0], os.path.join(MNIST_PATH, "conv2_y_q.txt"), 5)
    
    # Flatten
    y_dq = y_dq.reshape(-1, 16 * 5 * 5)
    if NUM_TEST_IMAGES == 1:
        save_file(y_q[0], y_dq[0], os.path.join(MNIST_PATH, "fc1_input.txt"), len(y_dq[0]))
    
    # FC1
    w_real = params['fc1']['w_real']
    b_real = params['fc1']['b_real']
    y = F.linear(y_dq, w_real, b_real)
    y = F.relu(y)
    y_q, y_dq = fake_quant(y, params['fc1']['output_scale'], params['fc1']['output_scale_inv'], zero_point=0)
    if NUM_TEST_IMAGES == 1:
        save_file(y_q[0], y_dq[0], os.path.join(MNIST_PATH, "fc2_input.txt"), len(y_dq[0]))
    
    # FC2
    w_real = params['fc2']['w_real']
    b_real = params['fc2']['b_real']
    y = F.linear(y_dq, w_real, b_real)
    y = F.relu(y)
    y_q, y_dq = fake_quant(y, params['fc2']['output_scale'], params['fc2']['output_scale_inv'], zero_point=0)
    if NUM_TEST_IMAGES == 1:
        save_file(y_q[0], y_dq[0], os.path.join(MNIST_PATH, "fc3_input.txt"), len(y_dq[0]))
    
    # FC3
    w_real = params['fc3']['w_real']
    b_real = params['fc3']['b_real']
    y = F.linear(y_dq, w_real, b_real)
    y_q, y_dq = fake_quant(y, params['fc3']['output_scale'], params['fc3']['output_scale_inv'], zero_point=0)
    if NUM_TEST_IMAGES == 1:
        save_file(y_q[0], y_dq[0], os.path.join(MNIST_PATH, "fc3_output.txt"), len(y_dq[0]))
    
    return y_dq

if __name__ == "__main__":
    params = {}
    for layer in layers:
        weight_shape = layers[layer]['weight_shape']
        bias_shape = layers[layer]['bias_shape']
        
        quantized_weight = load_quantized_tensor(
            os.path.join(MNIST_PATH, f"{layer}_weight_quantized.txt"), 
            weight_shape, 
            torch.int8
        )
        w_scale = load_scale(os.path.join(MNIST_PATH, f"{layer}_weight_scale_inv.txt"))
        
        quantized_bias = load_quantized_tensor(
            os.path.join(MNIST_PATH, f"{layer}_bias_quantized.txt"), 
            bias_shape, 
            torch.int16
        )
        b_scale = load_scale(os.path.join(MNIST_PATH, f"{layer}_bias_scale_inv.txt"))
        
        output_scale = load_scale(os.path.join(MNIST_PATH, f"{layer}_output_scale_inv.txt"))
        output_scale_inv = 1 / output_scale
        
        w_real = quantized_weight.float() * w_scale
        b_real = quantized_bias.float() * b_scale
        
        params[layer] = {
            'w_real': w_real,
            'b_real': b_real,
            'output_scale': output_scale,
            'output_scale_inv': output_scale_inv
        }

    input_scale = load_scale(os.path.join(MNIST_PATH, "input_scale_inv.txt"))
    input_scale_inv = 1 / input_scale

    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    test_dataset = datasets.MNIST(root=MNIST_PATH, train=False, download=True, transform=transform)
    
    if NUM_TEST_IMAGES > len(test_dataset):
        raise ValueError(f"NUM_TEST_IMAGES ({NUM_TEST_IMAGES}) is larger than the test dataset size ({len(test_dataset)})")
    indices = list(range(NUM_TEST_IMAGES))
    test_subset = Subset(test_dataset, indices)
    
    test_loader = DataLoader(dataset=test_subset, batch_size=1, shuffle=False)
    
    input_file_path = os.path.join(MNIST_PATH, "input_y_q_padd.txt")
    if os.path.exists(input_file_path):
        os.remove(input_file_path)
    
    correct = 0
    total = 0
    with torch.no_grad():
        for data, target in test_loader:
            output = inference(data, params, input_scale, input_scale_inv)
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()
            total += data.shape[0]

    accuracy = correct / total
    print(f"Test Accuracy on {NUM_TEST_IMAGES} images: {accuracy * 100:.2f}%")