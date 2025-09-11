OPCODES = {
    "ADD":  "0000",
    "SUB":  "0001",
    "ADDI": "0010",
    "MOV":  "0011",
    "CMP":  "0100",
    "XOR":  "0101",
    "AND":  "0110",
    "SHL":  "0111",
    "SHR":  "1000",
    "COM":  "1001",
    "INC":  "1010",
    "LD":   "1011",
    "ST":   "1100",
    "BR":   "1101",
    "BZ":   "1110",
    "BNZ":  "1111",
}

def reg_to_bin(reg: str) -> str:
    """Convert register name like R3 to 4-bit binary string."""
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

    # --- R-type: ADD, SUB, XOR, AND ---
    if instr in ["ADD", "SUB", "XOR", "AND"]:
        rd, rs1, rs2 = parts[1], parts[2], parts[3]
        return opcode + reg_to_bin(rd) + reg_to_bin(rs1) + reg_to_bin(rs2)

    # --- I-type: ADDI ---
    elif instr == "ADDI":
        rd, imm = parts[1], int(parts[2])
        return opcode + reg_to_bin(rd) + f"{imm & 0xFF:08b}"

    # --- MOV Rd, Rs ---
    elif instr == "MOV":
        rd, rs = parts[1], parts[2]
        return opcode + reg_to_bin(rd) + reg_to_bin(rs) + "0000"

    # --- CMP Rs1, Rs2 ---
    elif instr == "CMP":
        rs1, rs2 = parts[1], parts[2]
        return opcode + reg_to_bin(rs1) + reg_to_bin(rs2) + "0000"

    # --- SHL/SHR Rd, Rs ---
    elif instr in ["SHL", "SHR"]:
        rd, rs = parts[1], parts[2]
        return opcode + reg_to_bin(rd) + reg_to_bin(rs) + "0000"

    # --- COM / INC (unary ops) ---
    elif instr in ["COM", "INC"]:
        rd = parts[1]
        return opcode + reg_to_bin(rd) + "00000000"

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
    
def assemble(instructions, filename="./src/program.data"):
    """Assemble and write into 512-line memory file."""
    memory = ["00000000"] * 512
    addr = 511

    for instr in instructions:
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
        program.append(cmd)
        
    assemble(program)
    print("Assembled into program.data")
