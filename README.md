# ARM-like 16-bit Processor in VHDL

This project implements a simple **ARM-like 16-bit processor** in **VHDL** with a **16-bit fixed instruction format**. It is designed as an educational CPU architecture project and includes a custom Python assembler.

---

## ✨ Features

* **16 general-purpose registers**: `R0`–`R15` (each 16-bit wide).
* All **arithmetic and logical operations** are performed in 16-bit.
* **Instruction width**: 16 bits (fixed).
* **Two implementations** of the same instruction set: a **single-cycle** CPU and a **5-stage pipelined** CPU with forwarding, stalls and branch flushing.
* **Flag outputs**: `Zero (Z)`, `Sign (S)`, `Carry (C)` from the ALU.
* **Assembler included**: Write human-readable instructions and assemble to binary machine code.
* Fully **simulatable with GHDL** and viewable in **GTKWave**.

---

## 📖 Instruction Set (16-bit)

All instructions are encoded into **16 bits**: a 4-bit opcode followed by three 4-bit fields.

* **Register-type (R-type):**

  ```
  [4-bit opcode][4-bit Rd][4-bit Rs1][4-bit Rs2]
  ```
* **Immediate-type (I-type):**

  ```
  [4-bit opcode][4-bit Rd][8-bit signed immediate]
  ```
* **Memory-type (LD/ST):**

  ```
  [4-bit opcode][4-bit base register][8-bit offset]
  ```
* **ADD-ST:**

  ```
  [4-bit opcode][4-bit RX][8-bit address]
  ```
* **Branch-type:**

  ```
  [4-bit opcode][4-bit Rs (BZ/BNZ) or 0000 (BR)][8-bit signed offset]
  ```

8-bit immediates and offsets are **sign-extended** to 16 bits, so they range from `-128` to `127`.

### 🟢 Arithmetic & Logic

| Opcode | Instruction         | Operation                              |
|--------|---------------------|----------------------------------------|
| `0000` | `ADD  Rd, Rs1, Rs2` | Rd ← Rs1 + Rs2                         |
| `0001` | `SUB  Rd, Rs1, Rs2` | Rd ← Rs1 − Rs2                         |
| `0010` | `ADDI Rd, imm`      | Rd ← Rd + imm (`-128`..`127`)          |
| `0011` | `MOV  Rd, Rs`       | Rd ← Rs                                |
| `0101` | `XOR  Rd, Rs1, Rs2` | Rd ← Rs1 xor Rs2                       |
| `0110` | `AND  Rd, Rs1, Rs2` | Rd ← Rs1 and Rs2                       |
| `0111` | `OR   Rd, Rs1, Rs2` | Rd ← Rs1 or Rs2                        |
| `1000` | `NOT  Rd [, Rs]`    | Rd ← not Rs (`NOT Rd` means Rd ← not Rd) |
| `1001` | `SHL  Rd, Rs`       | Rd ← Rs << 1 (bit shifted out → Carry) |
| `1010` | `SHR  Rd, Rs`       | Rd ← Rs >> 1 (logical)                 |

### 🔵 Memory

| Opcode | Instruction      | Operation              |
|--------|------------------|------------------------|
| `1011` | `LD [Rb, off]`   | R1 ← Mem[Rb + off]     |
| `1100` | `ST [Rb, off]`   | Mem[Rb + off] ← R1     |
| `0100` | `ADD-ST [ADDR], RX` | Mem[ADDR] ← Mem[ADDR] + RX |

* `R1` is the implicit data register for both `LD` and `ST`.
* The offset is written in **hexadecimal** (`ST [R2, 10]` means offset 16).
* `ADD-ST` uses ADDR directly as the address (no base register), also in hexadecimal: `ADD-ST [A], R2` adds R2 to Mem[10]. No register changes.
* `ADD-ST` took the opcode of `CMP`, which was removed: `CMP` only set flags, and no instruction reads them.
* Data memory has **16 words of 16 bits** (`MemAddrWidth = 4` in `src/CPU.vhd` and `src/CPU_Pipeline.vhd`). Only the low 4 bits of `Rb + off` are used, so addresses wrap around after 15.

### 🟣 Branching

| Opcode | Instruction     | Operation                          |
|--------|-----------------|------------------------------------|
| `1101` | `BR  off`       | PC ← PC + off                      |
| `1110` | `BZ  Rs, off`   | PC ← PC + off if Rs = 0            |
| `1111` | `BNZ Rs, off`   | PC ← PC + off if Rs ≠ 0            |

* `off` counts **instructions** (not bytes), relative to the branch itself: `BR 1` is the next instruction, `BNZ R2, -1` jumps back one instruction.
* `BZ`/`BNZ` test the **register** `Rs`, not the Z flag.

### 🟠 Pseudo-instructions

| Instruction    | Expands to                          |
|----------------|-------------------------------------|
| `MOV Rd, imm`  | `XOR Rd, Rd, Rd` then `ADDI Rd, imm` |

`MOV Rd, imm` loads a number (`-128`..`127`) into a register. It takes **two** instruction slots, so count it as 2 when working out branch offsets that jump over it.

### 🚩 Flags

The ALU sets `Carry`, `Zero` and `Sign` for opcodes `0000`–`1010`. `Carry` is the carry/borrow out of bit 15, and `Sign` is bit 15 of the result. The flags can be watched in the waveform, but no instruction branches on them yet.

---

## 🧠 Memory Layout

* **Instruction memory**: 512 bytes (256 instructions), loaded from `src/program.data` at the start of simulation.
* Execution starts at address `0`, and the PC advances by 2 bytes per instruction. After the last address it wraps around to `0`.
* Empty memory is all zeros, which decodes as `ADD R0, R0, R0` (a harmless no-op).

---

## 🚀 Pipelined CPU

`src/CPU_Pipeline.vhd` runs the **same instruction set and the same `program.data`** as the single-cycle CPU (`src/CPU.vhd`), split into 5 stages so that up to 5 instructions are in progress at once:

```
IF  → fetch the instruction at PC
ID  → decode, read registers, detect load-use hazards
EX  → ALU, decide branches
MEM → data memory
WB  → write the register
```

It reuses the same ALU, Control Unit, Register Bank and memories. Programs give the same results on both CPUs, only the timing differs.

### Hazard handling

| Situation | Example | What the pipeline does |
|---|---|---|
| Using a result from the previous 1–2 instructions | `ADD R2, R1, R1` then `ADD R3, R2, R1` | **Forwarding**: the value goes straight from EX/MEM or MEM/WB to the ALU |
| Reading a register while it is being written | 3 instructions apart | **WB bypass**: ID reads the value being written |
| Storing a value computed just before | `ADDI R1, 9` then `ST [R2, 1]` | The R1 value for `ST` is forwarded too |
| Using R1 right after `LD` | `LD [R0, 3]` then `ADD R2, R1, R1` | **Stall** 1 cycle (the data comes from memory one stage too late to forward) |
| Taken branch | `BNZ R2, -1` | Decided in EX; the **2 instructions fetched after it are flushed** (never write anything) |

### ADD-ST in the two CPUs

`ADD-ST [ADDR], RX` reads memory, adds, and writes the same address back, which does not fit a pipeline where each instruction uses memory once.

* **Single-cycle CPU**: the data memory is read without waiting for the clock, so in one cycle Mem[ADDR] goes into the ALU, RX is added, and the sum is written back at the clock edge.
* **Pipelined CPU**: ID turns it into 3 **micro-ops**, one per cycle, using a hidden register **T** (register 16, which programs cannot name). Fetching is paused while they are issued:

  ```
  LD  T <- Mem[ADDR]
  ADD T <- T + RX        (waits 1 cycle for the LD: load-use stall)
  ST  Mem[ADDR] <- T
  ```

  The micro-ops are normal pipeline instructions, so the existing forwarding, stall and flush logic handles them.

### Performance

| Case | Cost |
|---|---|
| Normal instruction | 1 cycle (after 4 cycles to fill the pipeline) |
| `LD` followed by an instruction using R1 | +1 cycle |
| Taken branch (`BR`, or `BZ`/`BNZ` when they jump) | +2 cycles |
| `ADD-ST` | 4 cycles (3 micro-ops + 1 stall) |

The single-cycle CPU takes 1 cycle for every instruction, but in real hardware that cycle must be long enough for the whole instruction. A pipeline cycle only has to fit one stage, so the clock can be faster. In this simulation both CPUs use the same 8 ns clock, so the pipeline looks slower here.

### Run it

```bash
./run_pipeline.sh
```

Same assembler prompt as `run.sh`; the waveform is saved as `cpu_pipeline.ghw`.

### Tests

```bash
tests/run_tests.sh
```

Runs every `tests/*.asm` program (and the current `src/program.data`) on **both** CPUs side by side and checks that they make exactly the same register writes and memory writes in the same order (`src/TestBench/cpu_compare_TB.vhd`). The test programs target each hazard: `forwarding.asm`, `load_use.asm`, `branches.asm`, `add_st.asm`, plus `all_instructions.asm`. Add your own `.asm` file (comments start with `;`) or test one file with `tests/run_tests.sh tests/myprog.asm` (paths are relative to the repository root).

---

## ⚙️ Installation & Run

1. Install dependencies:

   ```bash
   sudo apt install ghdl gtkwave
   ```

2. Clone repository:

   ```bash
   git clone https://github.com/Alireza-Sobhdoost/ARMA-CPU.git
   cd ARMA-CPU
   ```

3. Make the run script executable:

   ```bash
   chmod +x run.sh run_pipeline.sh tests/run_tests.sh
   ```

4. Run the project:

   ```bash
   ./run.sh            # single-cycle CPU
   ./run_pipeline.sh   # pipelined CPU
   ```

   This starts the assembler, simulates the CPU for one pass through instruction memory (2100 ns), and opens the waveform in GTKWave.

---

## 📝 Python Assembler (16-bit)

A **custom Python assembler (`assembler.py`)** is included.

* Enter assembly instructions interactively, one per line. Commas are optional.
* Type `EXIT` to stop.
* A line with a mistake (unknown instruction, bad register, missing operand, immediate out of range) is rejected with an error and can be typed again.
* The **16-bit machine code** is written to `src/program.data`.

Example:

```
==Arma CLI==
MOV R1, 10
MOV R2, 4
ADD R3, R1, R2
EXIT
Assembled into program.data
```

After running, R1 = 10, R2 = 4 and R3 = 14.

A countdown loop:

```
MOV R2, 3
ADDI R2, -1
BNZ R2, -1
ADDI R3, 7
```

---

## 📊 Viewing Registers in GTKWave

`run.sh` saves the waveform as `cpu.ghw` (GHDL's format). Unlike VCD, it includes arrays such as the register file.

1. In the top-left tree, expand `top` → `cpu_tb` → `uut` → `register_bank_unit`.
2. Expand `registers` to see `registers[0]` … `registers[15]` (R0–R15).
3. Drag a register into the **Signals** pane and press **Zoom Fit**.
4. Right-click the signal → **Data Format** → **Decimal** to see decimal values.

Other useful signals: `uut` → `pc` and `ir` (the current instruction), and `register_bank_unit` → `writereg` / `writedata` (every register write).

For the pipeline (`cpu_pipeline.ghw`) the registers are under `top` → `cpu_pipeline_tb` → `uut` → `register_bank_unit`. To follow instructions through the stages, add the PC of each stage: `pc` (IF), `if_id_pc` (ID), `id_ex_pc` (EX), `ex_mem_pc` (MEM), `mem_wb_pc` (WB), plus `stall`, `flush` and `uopstep` (which ADD-ST micro-op is being issued).

Pipeline signal names tell you where they belong:

| Prefix | Meaning |
|---|---|
| `if_`, `id_`, `ex_`, `mem_`, `wb_` | Wires inside that stage (change during the cycle) |
| `if_id_`, `id_ex_`, `ex_mem_`, `mem_wb_` | Pipeline registers between two stages (change only at the clock edge) and belong to the instruction now in the later stage |
| `cu_` | Control Unit outputs, before ADD-ST micro-ops replace them |
| `rf_` | Register file outputs, before the WB bypass |

---

## 📁 Project Structure

```
assembler.py                         Python assembler → src/program.data
run.sh                               Assemble, simulate the single-cycle CPU, open GTKWave
run_pipeline.sh                      Same for the pipelined CPU
src/CPU.vhd                          Single-cycle CPU top level
src/CPU_Pipeline.vhd                 5-stage pipelined CPU top level
src/Control_Unit.vhd                 Opcode → control signals
src/ALU.vhd                          Arithmetic, logic, shifts, branch tests
src/Register_Bank.vhd                16 × 16-bit registers
src/Memory_Unit.vhd                  Data memory
src/Instruction_Memory_Unit.vhd      Instruction memory (loads program.data)
src/PC_Unit.vhd                      Program counter (single-cycle CPU)
src/TestBench/cpu_TB.vhd             Testbench used by run.sh
src/TestBench/cpu_pipeline_TB.vhd    Testbench used by run_pipeline.sh
src/TestBench/cpu_compare_TB.vhd     Runs both CPUs and compares them (tests/run_tests.sh)
src/TestBench/                       Unit testbenches (ALU, memory, PC, ...)
tests/*.asm                          Test programs for the pipeline hazards
tests/run_tests.sh                   Pipeline vs single-cycle comparison
```

---

## 📝 Notes

* Tested on **Linux** with GHDL + GTKWave.
* Instructions are **fixed-length 16-bit**.
* Designed for learning **VHDL CPU design, instruction set architecture, and assembler implementation**.

---

## 👤 Author

**Alireza Sobhdoost**
Guilan University – Computer Engineering

---
