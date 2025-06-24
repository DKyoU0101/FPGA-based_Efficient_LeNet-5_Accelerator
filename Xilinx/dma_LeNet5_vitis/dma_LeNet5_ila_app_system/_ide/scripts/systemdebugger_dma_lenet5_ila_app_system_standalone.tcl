# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: C:\FPGA_prj\CNN_FPGA\Xilinx\dma_LeNet5_vitis\dma_LeNet5_ila_app_system\_ide\scripts\systemdebugger_dma_lenet5_ila_app_system_standalone.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source C:\FPGA_prj\CNN_FPGA\Xilinx\dma_LeNet5_vitis\dma_LeNet5_ila_app_system\_ide\scripts\systemdebugger_dma_lenet5_ila_app_system_standalone.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
targets -set -filter {jtag_cable_name =~ "JTAG-ONB4 25163300135BA" && level==0 && jtag_device_ctx=="jsn-JTAG-ONB4-25163300135BA-23727093-0"}
fpga -file C:/FPGA_prj/CNN_FPGA/Xilinx/dma_LeNet5_vitis/dma_LeNet5_ila_app/_ide/bitstream/design_ILA_wrapper.bit
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw C:/FPGA_prj/CNN_FPGA/Xilinx/dma_LeNet5_vitis/design_ILA_wrapper/export/design_ILA_wrapper/hw/design_ILA_wrapper.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}
source C:/FPGA_prj/CNN_FPGA/Xilinx/dma_LeNet5_vitis/dma_LeNet5_ila_app/_ide/psinit/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow C:/FPGA_prj/CNN_FPGA/Xilinx/dma_LeNet5_vitis/dma_LeNet5_ila_app/Debug/dma_LeNet5_ila_app.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "*A9*#0"}
con
