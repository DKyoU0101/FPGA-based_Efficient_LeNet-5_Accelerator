#////////////////////////////////////////////////////////////////////////////////
# Company: Personal
# Engineer: dkyou0101
# 
# Create Date: 2025.02.13
# Associated Filename: sim_script.tcl
# Project Name: CNN_FPGA
# Tool Versions: Vivado/Vitis 2022.2
# Purpose: To run simulation
# Revision: 0.01 - File Created
# Additional Comments:
# 
#////////////////////////////////////////////////////////////////////////////////

set CURR_WAVE [current_wave_config]

##====================================================================
## Read params.txt
##====================================================================
if {![file exists "params.txt"]} {
    puts "Error: params.txt not found."
    exit
}
set file [open "params.txt" r]

set MODE [gets $file]
if {[eof $file]} {
    puts "Error: No content in params.txt."
    close $file
    exit
}

set TB_MODULE [gets $file]
set CORE_MODULE [gets $file]
if {[string equal -nocase $MODE "all"]} {
    set signals [get_objects -r /*]
} elseif {[string equal -nocase $MODE "tb"]} {
    set signals [get_objects /tb_$TB_MODULE/*]
} elseif {[string equal -nocase $MODE "top"]} {
    set signals [get_objects /tb_$TB_MODULE/u_$TB_MODULE\_top/*]
} elseif {[string equal -nocase $MODE "core"]} {
    set signals [get_objects /tb_$TB_MODULE/u_$TB_MODULE\_top/u_$CORE_MODULE/*]
} elseif {[string equal -nocase $MODE "sub"]} {
    set SUB_MODULE [gets $file]
    set signals [get_objects /tb_$TB_MODULE/u_$TB_MODULE\_top/u_$CORE_MODULE/$SUB_MODULE/*]
} else {
    puts "Error: Not Correct MODE in params.txt."
    close $file
    exit
}

close $file


##====================================================================
## Add wave
##====================================================================
if { [string length $CURR_WAVE] == 0 } {
    if { [llength [get_objects]] > 0} {
        foreach sig_each $signals {
            set sig_name [file tail $sig_each]
            if {[string equal -nocase $MODE "core"] || [string equal -nocase $MODE "sub"]} {
        ## define add_wave option
        ##----------------------------------------------------------------------
        if {[string match "*clk" $sig_name] || [string match "*areset" $sig_name] || [string match "*rst_n" $sig_name]} {
            add_wave [list $sig_each] -color white
        } elseif {[string match "c_state*" $sig_name]} {
            add_wave [list $sig_each] -color orange
        } elseif {[string match "i_*" $sig_name] || ([string match "s_axis_*" $sig_name] && 
            ![string match "s_axis_tready" $sig_name]) || [string match "m_axis_tready" $sig_name]} {
            add_wave [list $sig_each] -color #e7e600
        } elseif {[string match "o_*" $sig_name] || [string match "m_axis_*" $sig_name]  || [string match "s_axis_tready" $sig_name]} {
            add_wave [list $sig_each] -color #a667cf
        } elseif {[string match "c_*" $sig_name]} {
            add_wave [list $sig_each] -color #468bcc
        } elseif {[string match "b_*" $sig_name]} {
            add_wave [list $sig_each] -color gray
        } elseif {[string match "r_*" $sig_name]} {
            if {[string match "*_cnt" $sig_name]} {
                add_wave [list $sig_each] -radix unsigned -color aqua
            } else {
                add_wave [list $sig_each] -color lime
            }
        } elseif {[string match "w_*" $sig_name] || [string match "n_*" $sig_name]} {
            add_wave [list $sig_each] -color #056945
        } elseif {!([string match "g_*" $sig_name])} {
            add_wave [list $sig_each] -color green
        }
        ##----------------------------------------------------------------------
            } elseif {!([string match "ctrl" $sig_name] || [string match "m00_axi" $sig_name])} {
                add_wave [list $sig_each]
            }
        }
        set_property needs_save false [current_wave_config]
    } else {
        send_msg_id Add_Wave-1 WARNING "No top level signals found. Simulator will start without a wave window. If you want to open a wave window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console."
    }
}

##====================================================================
## Run Simulation
##====================================================================
run 1000ns
