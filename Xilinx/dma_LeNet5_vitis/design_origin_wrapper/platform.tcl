# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\FPGA_prj\CNN_FPGA\Xilinx\dma_LeNet5_vitis\design_origin_wrapper\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\FPGA_prj\CNN_FPGA\Xilinx\dma_LeNet5_vitis\design_origin_wrapper\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {design_origin_wrapper}\
-hw {C:\FPGA_prj\CNN_FPGA\Xilinx\dma_LeNet5_prj\design_origin_wrapper.xsa}\
-out {C:/FPGA_prj/CNN_FPGA/Xilinx/dma_LeNet5_vitis}

platform write
domain create -name {standalone_ps7_cortexa9_0} -display-name {standalone_ps7_cortexa9_0} -os {standalone} -proc {ps7_cortexa9_0} -runtime {cpp} -arch {32-bit} -support-app {empty_application}
platform generate -domains 
platform active {design_origin_wrapper}
domain active {zynq_fsbl}
domain active {standalone_ps7_cortexa9_0}
platform generate -quick
bsp reload
domain active {zynq_fsbl}
bsp reload
domain active {standalone_ps7_cortexa9_0}
bsp setlib -name xilffs -ver 4.8
bsp config use_trim "false"
bsp config use_strfunc "2"
bsp config use_strfunc "2"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
platform generate
