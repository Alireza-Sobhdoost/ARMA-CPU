OPCODES = {
    "ADD":  "0000",
    "SUB":  "0001",
    "ADDI": "0010",
    "MOV":  "0011",
    "ADD-ST": "0100",
    "XOR":  "0101",
    "AND":  "0110",
    "OR":  "0111",
    "NOT":  "1000",
    "SHL":  "1001",
    "SHR":  "1010",
    "LD":   "1011",
    "ST":   "1100",
    "BR":   "1101",
    "BZ":   "1110",
    "BNZ":  "1111",
}

def reg_to_bin(reg: str) -> str:
    """Convert register name like R3 to 4-bit binary string."""
    if reg[:1].upper() != "R" or not reg[1:].isdigit() or int(reg[1:]) > 15:
        raise ValueError(f"Expected a register R0-R15, got '{reg}'")
    return f"{int(reg[1:]):04b}"

def encode_instruction(line: str) -> str:
    """
    Convert assembly into a 16-bit binary string.
    """
    line = line.replace(",", "").replace("[", "").replace("]", "")
    parts = line.split()
    instr = parts[0].upper()

    if instr not in OPCODES:
        raise ValueError(f"Unknown instruction: {instr}")

    opcode = OPCODES[instr]

    # --- R-type: ADD, SUB, XOR, AND, OR ---
    if instr in ["ADD", "SUB", "XOR", "AND", "OR"]:
        rd, rs1, rs2 = parts[1], parts[2], parts[3]
        return opcode + reg_to_bin(rd) + reg_to_bin(rs1) + reg_to_bin(rs2)

    # --- I-type: ADDI ---
    elif instr == "ADDI":
        rd, imm = parts[1], int(parts[2])
        # The CPU sign-extends the 8-bit immediate
        if not -128 <= imm <= 127:
            raise ValueError(f"Immediate must be -128..127, got {imm}")
        return opcode + reg_to_bin(rd) + f"{imm & 0xFF:08b}"

    # --- MOV Rd, Rs ---
    elif instr == "MOV":
        rd, rs = parts[1], parts[2]
        return opcode + reg_to_bin(rd) + reg_to_bin(rs) + "0000"

    # --- ADD-ST [ADDR], RX: Mem[ADDR] <- Mem[ADDR] + RX (ADDR in hex, like LD/ST) ---
    elif instr == "ADD-ST":
        addr, rx = int(parts[1], 16), parts[2]
        if not 0 <= addr <= 0xFF:
            raise ValueError(f"ADD-ST address must be 0..FF, got {parts[1]}")
        return opcode + reg_to_bin(rx) + f"{addr:08b}"

    # --- SHL/SHR Rd, Rs ---
    elif instr in ["SHL", "SHR"]:
        rd, rs = parts[1], parts[2]
        return opcode + reg_to_bin(rd) + reg_to_bin(rs) + "0000"

    # --- NOT Rd (Rd <- not Rd) or NOT Rd, Rs (Rd <- not Rs) ---
    elif instr == "NOT":
        rd = parts[1]
        rs = parts[2] if len(parts) > 2 else rd
        return opcode + reg_to_bin(rd) + reg_to_bin(rs) + "0000"

    # --- LD / ST: LD R1, [R2, 0x4] or ST [R2, 0x4], R1 ---
    elif instr in ["LD", "ST"]:
        # Parse base and offset
        base = parts[1]
        offset = int(parts[2], 16)
        
        # Assemble instruction: 4-bit opcode + 4-bit base + 8-bit offset
        # R1 is implicit in the CPU, so we don't encode Rd
        return opcode + reg_to_bin(base) + f"{offset & 0xFF:08b}"

    # --- Branches ---
    elif instr == "BR":   # BR offset
        offset = int(parts[1])
        return opcode + "0000" + f"{offset & 0xFF:08b}"

    elif instr in ["BZ", "BNZ"]:  # BZ R1, offset
        rs, offset = parts[1], int(parts[2])
        return opcode + reg_to_bin(rs) + f"{offset & 0xFF:08b}"

    else:
        raise ValueError(f"Encoding not implemented for {instr}")

def expand_pseudo(line: str) -> list:
    """
    Expand pseudo-instructions into real ones.
    MOV Rd, imm  ->  XOR Rd, Rd, Rd ; ADDI Rd, imm   (load immediate)
    Note: a pseudo-instruction takes 2 slots, so count both in branch offsets.
    """
    parts = line.replace(",", " ").split()
    if len(parts) == 3 and parts[0].upper() == "MOV" and parts[2][:1].upper() != "R":
        rd, imm = parts[1], parts[2]
        return [f"XOR {rd}, {rd}, {rd}", f"ADDI {rd}, {imm}"]
    return [line]

def assemble(instructions, filename="./src/program.data"):
    """Assemble and write into 512-line memory file."""
    memory = ["00000000"] * 512
    addr = 511

    real = [r for instr in instructions for r in expand_pseudo(instr)]
    for instr in real:
        binary = encode_instruction(instr)
        low, high = binary[:8], binary[8:]
        memory[addr] = high
        memory[addr - 1] = low
        addr -= 2

    with open(filename, "w") as f:
        f.write("\n".join(memory))


if __name__ == "__main__":
    # Example program
    # program = [
    #     "ADD R1, R2, R3",
    #     "SUB R4, R5, R6"
    # ]
    print("==Arma CLI==")
    program = []
    while True :
        cmd = input()
        if cmd == "EXIT" :
            break
        if not cmd.strip():
            continue
        # Check each line as it is typed so a mistake can be re-entered
        try:
            for real in expand_pseudo(cmd):
                encode_instruction(real)
        except (ValueError, IndexError) as e:
            msg = str(e) if isinstance(e, ValueError) else "missing operand"
            print(f"Error: {msg} -- line ignored, try again")
            continue
        program.append(cmd)
        
    assemble(program)
    print("Assembled into program.data")
