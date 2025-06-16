#!/usr/bin/env python

#////////////////////////////////////////////////////////////////////////////////
# Company: Personal
# Engineer: dkyou0101
# 
# Create Date: 2025.02.20
# Associated Filename: run.py
# Project Name: CNN_FPGA
# Tool Versions: Vivado/Vitis 2022.2
# Purpose: To run simulation
# Revision: 0.01 - File Created
#           0.1(25.05.02) - minor rivision
# Additional Comments:
# 
#////////////////////////////////////////////////////////////////////////////////

import os
import argparse
import sys

##====================================================================
## User Define
##====================================================================
TB_NAME      = "dma_LeNet5"
MODULE_NAME  = "LeNet5_core_ip"
RANDOM_SEED  = "5"
REF_LOOP_NUM = "5"
RTL_LOOP_NUM = "5"
##====================================================================


CLEAN_CMD1  = "rm -rf *xe* *xs* *.wdb* *trace* *xv* *webtalk* *backup* .Xil .hbs *.log *.str *.jou *Zone.Identifier"
CLEAN_CMD2  = "find ../ -type f -name \"*Zone.Identifier\" -exec rm {} \;"
REF_C_PATH = "../design/ref_cpp/"
TRACE_PATH = "../design/ref_cpp/trace/"
RTL_V_PATH = "../design/rtl_v/"
AXI_TB_PATH = "../design/axi_tb/"
PROTOINST_FP = "../design/protoinst_files/proto_sim.protoinst"
REF_C_RESULT = "ref_c.txt"
RTL_V_RESULT = "rtl_v.txt"
WF_TCL_FILE = "sim_script.tcl"
MODULE_TXT = "params.txt"
RTL_V_LISTFILE = "rtl_v_list_file.f"
AXI_TB_LISTFILE = "axi_tb_list_file.f"

##====================================================================
## Main
##====================================================================
def main() :
    print ("Module Name: " + TB_NAME)
    args = parse_args()
    if (args.clean) :
        run_clean()
        print ("Clean Done!!")
    elif (args.refc) :    
        run_ref_c()
        print ("Success Ref_cpp Simulation!!")
    elif (args.nwf | args.allwf | args.tbwf | args.twf | args.cwf | args.swf) :  
        run_rtl_v_sim(args)
        print ("Success RTL_v Simulation!!")
    elif (args.diff) :
        check_result()
        print ("Success Compare Ref_cpp vs RTL txt File!!")
    else :
        print ("Error Command run.py Option!!")
        sys.exit(1)
        
##====================================================================
## setup_cmdargs
##====================================================================
def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-clean"    ,dest="clean"     ,action="store_true"    ,help="Clean in Folder")
    parser.add_argument("-refc"     ,dest="refc"      ,action="store_true"    ,help="Generate Reference file using Cpp")
    parser.add_argument("-nwf"      ,dest="nwf"       ,action="store_true"    ,help="Vivado sim without waveform")
    parser.add_argument("-allwf"    ,dest="allwf"     ,action="store_true"    ,help="All Signal Vivado sim with waveform")
    parser.add_argument("-tbwf"     ,dest="tbwf"      ,action="store_true"    ,help="Testbench Vivado sim with waveform")
    parser.add_argument("-twf"      ,dest="twf"       ,action="store_true"    ,help="Top Module Vivado sim with waveform")
    parser.add_argument("-cwf"      ,dest="cwf"       ,action="store_true"    ,help="Core Module Vivado sim with waveform")
    parser.add_argument("-swf"      ,dest="swf"       ,action="store_true"    ,help="Submoule Vivado sim with waveform")
    parser.add_argument("-diff"     ,dest="diff"      ,action="store_true"    ,help="Diff ref vs rtl file")
    args = parser.parse_args()
    return args
       
##====================================================================
## Run Clean
##====================================================================
def run_clean():
    run_cmd("rm -rf " + TRACE_PATH + "*.txt")
    run_cmd(CLEAN_CMD1)
    run_cmd(CLEAN_CMD2)
 
##====================================================================
## Run Ref_cpp sim
##====================================================================
def run_ref_c():
    ref_cmd = "make -C " + REF_C_PATH + " TARGET='" + MODULE_NAME + "'"
    run_cmd(ref_cmd)
    print ("Success run Makefile!")
    
    ref_cmd = REF_C_PATH + MODULE_NAME + " " + RANDOM_SEED + " " + REF_LOOP_NUM
    run_cmd(ref_cmd)

##====================================================================
## Run RTL_v sim
##====================================================================
def run_rtl_v_sim(args):
    if(args.swf):
        print("Enter the Submodule Instance Path! (Do NOT include Top Module Instance Name)")
        print("ex) tb_cnn/u_cnn/u_module_A/u_module_B -> u_module_A/u_module_B")
        SUB_MODULE = input()
        
    gen_rtl_v_list_file()
    gen_axi_tb_list_file()
    
    # cmd = "xvlog -i " + RTL_V_PATH + " ./tb_" + MODULE_NAME + ".v " + RTL_V_PATH + "*.v" + " -d TEST_NUM=100"
    cmd = "xvlog -i " + RTL_V_PATH + " --sv -L xilinx_vip -f ./" + RTL_V_LISTFILE +" -f ./" + AXI_TB_LISTFILE + " ./tb_" + TB_NAME + ".sv -d LOOP_NUM=" + RTL_LOOP_NUM
    run_cmd(cmd)
    
    # if use .vhd file
    cmd = "xvhdl ./*.vhd"
    run_cmd(cmd)
    
    # cmd = "xelab tb_" + MODULE_NAME + " -debug wave -s tb_" + MODULE_NAME + " -d TEST_NUM=100"  ## do not use -generic
    cmd = "xelab tb_" + TB_NAME + " -L xilinx_vip -debug all -s tb_" + TB_NAME + " --timescale 1ns/10ps -d LOOP_NUM=" + RTL_LOOP_NUM  ## do not use -generic
    run_cmd(cmd)
    
    if(args.nwf) :
        cmd = "xsim tb_" + TB_NAME + " -R"
    else :
        cmd = "xsim tb_" + TB_NAME + " -gui -wdb simulate_xsim_tb_" + TB_NAME + ".wdb -tclbatch " + WF_TCL_FILE + " -protoinst " + PROTOINST_FP
        if(args.allwf) :
            SIM_MODE = "all"
            write_wf_param(args, SIM_MODE)
        elif(args.tbwf) :
            SIM_MODE = "tb"
            write_wf_param(args, SIM_MODE)
        elif(args.twf) :
            SIM_MODE = "top"
            write_wf_param(args, SIM_MODE)
        elif(args.cwf) :
            SIM_MODE = "core"
            write_wf_param(args, SIM_MODE)
        else :
            write_swf_param(SUB_MODULE)
    run_cmd(cmd)

##====================================================================
## Check result
##====================================================================
def check_result():
    check_cmd = "diff " + TRACE_PATH + REF_C_RESULT + " " + TRACE_PATH + RTL_V_RESULT
    run_cmd(check_cmd)
 
    
##====================================================================
## Write TXT used tcl parameter
##==================================================================== 
def write_wf_param(args, SIM_MODE):
    with open(MODULE_TXT, "w") as f:
        f.write(f"{SIM_MODE}\n")
        f.write(f"{TB_NAME}\n")
        f.write(f"{MODULE_NAME}\n")
        f.close()

def write_swf_param(SUB_MODULE):
    with open(MODULE_TXT, "w") as f:
        f.write(f"sub\n")
        f.write(f"{TB_NAME}\n")
        f.write(f"{MODULE_NAME}\n")
        f.write(f"{SUB_MODULE}\n")
        f.close()

##====================================================================
## Generate and Write Listfile
##==================================================================== 
def gen_rtl_v_list_file(project_dir = RTL_V_PATH, output_file = RTL_V_LISTFILE):
    with open(output_file, "w") as f:
        for root, _, files in os.walk(project_dir):
            for file in files:
                if file.endswith(".v"):
                    file_path = os.path.join(root, file)
                    f.write(file_path + "\n")

def gen_axi_tb_list_file(project_dir = AXI_TB_PATH, output_file = AXI_TB_LISTFILE):
    with open(output_file, "w") as f:
        for root, _, files in os.walk(project_dir):
            for file in files:
                if file.endswith(".v") or file.endswith(".sv"):
                    file_path = os.path.join(root, file)
                    f.write(file_path + "\n")

##====================================================================
## etc
##====================================================================
def run_cmd(cmd):
    print (cmd)
    if os.system(cmd):
        print ("Error command runned incorrectly...")
        sys.exit(1)

if __name__ == "__main__":
    main()
