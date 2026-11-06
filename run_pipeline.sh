#!/bin/bash

# Clean start
rm -f work-obj*.cf cpu_pipeline.ghw

python3 assembler.py || exit 1

# Analyze with Synopsys option (all files in src/)
ghdl -a -fsynopsys src/ALU.vhd
ghdl -a -fsynopsys src/Instruction_Memory_Unit.vhd
ghdl -a -fsynopsys src/Memory_Unit.vhd
ghdl -a -fsynopsys src/Register_Bank.vhd
ghdl -a -fsynopsys src/Control_Unit.vhd
ghdl -a -fsynopsys src/CPU_Pipeline.vhd
ghdl -a -fsynopsys src/TestBench/cpu_pipeline_TB.vhd

# Elaborate and simulate
ghdl -e -fsynopsys cpu_pipeline_tb
# 256 instructions x 8 ns clock period = one pass through instruction memory
# (plus a few cycles for the pipeline to fill)
ghdl -r -fsynopsys cpu_pipeline_tb --wave=cpu_pipeline.ghw --stop-time=2200ns --ieee-asserts=disable-at-0

# View waveform (GHW format, unlike VCD, includes arrays such as the register file)
gtkwave cpu_pipeline.ghw

