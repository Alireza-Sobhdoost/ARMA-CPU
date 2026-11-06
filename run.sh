#!/bin/bash

# Clean start
rm -f work-obj*.cf cpu.vcd cpu.ghw

python3 assembler.py || exit 1

# Analyze with Synopsys option (all files in src/)
ghdl -a -fsynopsys src/ALU.vhd
ghdl -a -fsynopsys src/Instruction_Memory_Unit.vhd
ghdl -a -fsynopsys src/Memory_Unit.vhd
ghdl -a -fsynopsys src/PC_Unit.vhd
ghdl -a -fsynopsys src/Register_Bank.vhd
ghdl -a -fsynopsys src/Control_Unit.vhd
ghdl -a -fsynopsys src/CPU.vhd
ghdl -a -fsynopsys src/cpu_tb.vhd

# Elaborate and simulate
ghdl -e -fsynopsys cpu_tb
# 256 instructions x 8 ns clock period = one pass through instruction memory
ghdl -r -fsynopsys cpu_tb --wave=cpu.ghw --stop-time=2100ns --ieee-asserts=disable-at-0

# View waveform (GHW format, unlike VCD, includes arrays such as the register file)
gtkwave cpu.ghw

