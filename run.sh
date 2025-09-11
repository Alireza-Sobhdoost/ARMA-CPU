#!/bin/bash

# Clean start
rm -f work-obj*.cf cpu.vcd

python3 assembler.py

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
ghdl -r -fsynopsys cpu_tb --vcd=cpu.vcd

# View waveform
gtkwave cpu.vcd

