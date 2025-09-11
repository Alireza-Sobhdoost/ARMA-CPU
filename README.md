# ARM-like 8-bit Processor in VHDL

This project implements a simple **ARM-like 8-bit processor** in **VHDL** with a **16-bit fixed instruction format**. It is designed as an educational CPU architecture project and includes a custom Python assembler.

---

## ✨ Features

* **8 general-purpose registers**: `R0`–`R7` (each 8-bit wide).
* All **arithmetic and logical operations** are performed in 8-bit.
* **Instruction width**: 16 bits (fixed).
* **Flag support**: `Zero (Z)`, `Sign (S)`, `Carry (C)`.
* **Assembler included**: Write human-readable instructions and assemble to binary machine code.
* Fully **simulatable with GHDL** and viewable in **GTKWave**.

---

## 📖 Instruction Set (16-bit)

All instructions are encoded into **16 bits**.
General format examples:

* **Register-type (R-type):**

  ```
  [4-bit opcode][1 free bit][3-bit Rd][3-bit Rb][5 bits unused/imm]
  ```
* **Immediate-type (I-type):**

  ```
  [4-bit opcode][1 free bit][3-bit Rd][8-bit immediate]
  ```
* **Memory-type (LD/ST):**

  ```
  [4-bit opcode][1 free bit][3-bit base register][8-bit offset]
  ```
* **Branch-type:**

  ```
  [4-bit opcode][12-bit signed offset]
  ```

### 🟢 Arithmetic & Logic

* `ADD   R1, R2, R3`   → R1 ← R2 + R3
* `ADC   R1, R2, R3`   → R1 ← R2 + R3' + 1
* `SUB   R1, R2, R3`   → R1 ← R2 - R3
* `ADDI  R1, xx`       → R1 ← R1 + xx
* `MOV   R1, R2`       → R1 ← R2
* `CMP   R1, R2`       → Compare R1,R2 (set flags)
* `SHL   R1, R0`       → Shift left
* `SHR   R1, R0`       → Shift right
* `NOT   R1`           → Bitwise NOT
* `INC   R1`           → Increment R1
* `XOR   R1, R2, R3`   → XOR
* `AND   R1, R2, R3`   → AND
* `COM   R1`           → Two’s complement

### 🔵 Memory

* `LD   [R2+yy]`   → Load from memory to R1
* `ST   [R2+yy]`   → Store R1 to memory

### 🟣 Branching

* `BR   zz`            → PC ← PC + zz
* `BZ   zz`            → PC ← PC + zz if Z=1
* `BNZ  zz`            → PC ← PC + zz if Z=0

---

## ⚙️ Installation & Run

1. Install dependencies:

   ```bash
   sudo apt install ghdl gtkwave
   ```

2. Clone repository:

   ```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo
   ```

3. Make the run script executable:

   ```bash
   chmod +x run.sh
   ```

4. Run the project:

   ```bash
   ./run.sh
   ```

---

## 📝 Python Assembler (16-bit)

A **custom Python assembler (`assembler.py`)** is included.

* Enter assembly instructions interactively.
* Type `EXIT` to stop.
* Assembler generates **16-bit machine code**.

Example:

```
ADDI R1, 10
ST [R2, 5]
EXIT
```

Output (binary machine code):

```
i_1 = 00100001 00001010

i_2 = 11000010 00000101
...
```

---

## 📊 Notes

* Tested on **Linux** with GHDL + GTKWave.
* Instructions are **fixed-length 16-bit**.
* Designed for learning **VHDL CPU design, instruction set architecture, and assembler implementation**.

---

## 👤 Author

**Alireza Sobhdoost**
Guilan University – Computer Engineering

---
