# ARM-like 16-bit Processor in VHDL

This project implements a simple **ARM-like 16-bit processor** in **VHDL** with a **16-bit fixed instruction format**. It is designed as an educational CPU architecture project and includes a custom Python assembler.

---

## ✨ Features

* **16 general-purpose registers**: `R0`–`R15` (each 16-bit wide).
* All **arithmetic and logical operations** are performed in 16-bit.
* **Instruction width**: 16 bits (fixed), single-cycle execution.
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
| `0100` | `CMP  Rs1, Rs2`     | Flags ← Rs1 − Rs2 (no register written) |
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

* `R1` is the implicit data register for both `LD` and `ST`.
* The offset is written in **hexadecimal** (`ST [R2, 10]` means offset 16).
* Data memory has **16 words of 16 bits** (`MemAddrWidth = 4` in `src/CPU.vhd`). Only the low 4 bits of `Rb + off` are used, so addresses wrap around after 15.

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
   chmod +x run.sh
   ```

4. Run the project:

   ```bash
   ./run.sh
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

---

## 📁 Project Structure

```
assembler.py                    Python assembler → src/program.data
run.sh                          Assemble, simulate and open GTKWave
src/CPU.vhd                     Top level: datapath wiring
src/Control_Unit.vhd            Opcode → control signals
src/ALU.vhd                     Arithmetic, logic, shifts, branch tests
src/Register_Bank.vhd           16 × 16-bit registers
src/Memory_Unit.vhd             Data memory
src/Instruction_Memory_Unit.vhd Instruction memory (loads program.data)
src/PC_Unit.vhd                 Program counter
src/cpu_tb.vhd                  CPU testbench used by run.sh
src/TestBench/                  Unit testbenches (ALU, memory, PC, ...)
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
