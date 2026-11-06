library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

-- 5-stage pipelined Arma CPU:  IF -> ID -> EX -> MEM -> WB
-- Same instruction set and ports as CPU.vhd, so the same program.data runs
-- on both. Hazards are handled in hardware:
--   * Forwarding  : EX/MEM and MEM/WB results go straight back to the EX stage
--                   (ALU inputs and the value that ST stores)
--   * WB bypass   : a register written in WB is read with its new value in ID
--   * Load-use    : an instruction that needs a register right after it is
--                   loaded waits 1 cycle
--   * Branches    : decided in EX; a taken branch flushes the 2 instructions
--                   fetched after it
-- ADD-ST [ADDR], RX (Mem[ADDR] <- Mem[ADDR] + RX) is split in ID into 3
-- micro-ops that use a hidden register T:
--   LD T <- Mem[ADDR] ;  ADD T <- T + RX ;  ST Mem[ADDR] <- T
entity CPU_Pipeline is
    Port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
		IMR : in std_logic;
		IMW : in Std_logic;
		INST : in Std_logic_vector(15 downto 0)
    );
end CPU_Pipeline;

architecture Behavioral of CPU_Pipeline is
    constant RegBits      : integer := 16;    -- data / register width
    constant Regs_in_bit  : integer := 4;     -- 16 registers -> 4-bit register fields
    constant Reg_Addr_Bits: integer := Regs_in_bit + 1;  -- +1 bit for the hidden register T
    constant MemAddrWidth : integer := 4;     -- data memory address width
    constant PC_range     : integer := 2**9;  -- instruction memory size in bytes

    subtype word     is STD_LOGIC_VECTOR(RegBits - 1 downto 0);
    subtype reg_addr is STD_LOGIC_VECTOR(Reg_Addr_Bits - 1 downto 0);
    constant R1_ADDR : reg_addr := "00001";   -- implicit data register of LD / ST
    constant T_ADDR  : reg_addr := "10000";   -- hidden register T (R16) used by ADD-ST

    -- Newest value of register 'src' for the EX stage
    function forward(src      : reg_addr; reg_val   : word;
                     exmem_we : std_logic; exmem_rd : reg_addr; exmem_val : word;
                     memwb_we : std_logic; memwb_rd : reg_addr; memwb_val : word) return word is
    begin
        if exmem_we = '1' and exmem_rd = src then
            return exmem_val;
        elsif memwb_we = '1' and memwb_rd = src then
            return memwb_val;
        else
            return reg_val;
        end if;
    end function;

    ---------------------------------------------------------------- IF
    signal PC                  : integer range 0 to PC_range - 1 := 0;
    signal IF_Instr            : STD_LOGIC_VECTOR(15 downto 0);

    ---------------------------------------------------------------- IF/ID
    signal IF_ID_Valid         : STD_LOGIC := '0';
    signal IF_ID_Instr         : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal IF_ID_PC            : integer range 0 to PC_range - 1 := 0;

    ---------------------------------------------------------------- ID
    signal ID_OpCode           : STD_LOGIC_VECTOR(3 downto 0);
    signal ID_R1, ID_R2, ID_R3 : reg_addr;
    signal ID_Imm              : word;
    -- Control Unit outputs
    signal CU_RegWrite, CU_MemRead, CU_MemWrite, CU_ALUSrc : STD_LOGIC;
    signal CU_Branch, CU_Reg2Loc, CU_MemToReg              : STD_LOGIC;
    signal CU_ALUOp            : STD_LOGIC_VECTOR(3 downto 0);
    -- What ID sends to EX (the instruction, or an ADD-ST micro-op)
    signal ID_RegWrite, ID_MemRead, ID_MemWrite, ID_ALUSrc : STD_LOGIC;
    signal ID_Branch, ID_MemToReg, ID_AbsAddr              : STD_LOGIC;
    signal ID_ALUOp            : STD_LOGIC_VECTOR(3 downto 0);
    signal ID_Rs1, ID_Rs2, ID_WriteReg, ID_StoreReg : reg_addr;
    signal RF_RD1, RF_RD2, RF_R1   : word;   -- register file outputs
    signal ID_RD1, ID_RD2, ID_R1Val, ID_StoreVal : word;  -- after the WB bypass
    -- ADD-ST micro-op sequencer
    signal ID_IsAddSt          : STD_LOGIC;
    signal UopStep             : integer range 0 to 2 := 0;
    signal UopHold             : STD_LOGIC;
    -- Hazard control
    signal Stall, Flush        : STD_LOGIC;

    ---------------------------------------------------------------- ID/EX
    signal ID_EX_RegWrite, ID_EX_MemRead, ID_EX_MemWrite : STD_LOGIC := '0';
    signal ID_EX_ALUSrc, ID_EX_Branch, ID_EX_MemToReg    : STD_LOGIC := '0';
    signal ID_EX_AbsAddr       : STD_LOGIC := '0';
    signal ID_EX_ALUOp         : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal ID_EX_Rs1, ID_EX_Rs2, ID_EX_WriteReg, ID_EX_StoreReg : reg_addr := (others => '0');
    signal ID_EX_RD1, ID_EX_RD2, ID_EX_StoreVal, ID_EX_Imm : word := (others => '0');
    signal ID_EX_PC            : integer range 0 to PC_range - 1 := 0;

    ---------------------------------------------------------------- EX
    signal EX_A, EX_RD2, EX_B, EX_StoreData, EX_ALUResult, EX_Result : word;
    signal EX_Carry, EX_Zero, EX_Sign, EX_UnB : STD_LOGIC;
    signal EX_Fwd_WE           : STD_LOGIC;
    signal EX_Target           : integer range 0 to PC_range - 1;

    ---------------------------------------------------------------- EX/MEM
    signal EX_MEM_RegWrite, EX_MEM_MemRead, EX_MEM_MemWrite, EX_MEM_MemToReg : STD_LOGIC := '0';
    signal EX_MEM_WriteReg     : reg_addr := (others => '0');
    signal EX_MEM_ALUResult, EX_MEM_StoreData : word := (others => '0');
    signal EX_MEM_PC           : integer range 0 to PC_range - 1 := 0;

    ---------------------------------------------------------------- MEM
    signal MEM_DataOut         : word;

    ---------------------------------------------------------------- MEM/WB
    signal MEM_WB_RegWrite, MEM_WB_MemToReg : STD_LOGIC := '0';
    signal MEM_WB_WriteReg     : reg_addr := (others => '0');
    signal MEM_WB_ALUResult, MEM_WB_MemData : word := (others => '0');
    signal MEM_WB_PC           : integer range 0 to PC_range - 1 := 0;

    ---------------------------------------------------------------- WB
    signal WB_WriteData        : word;

begin

    ------------------------------------------------------------------
    -- IF : fetch the instruction at PC
    ------------------------------------------------------------------
    Instruction_Memory_Unit_Unit: entity work.Instruction_Memory_Unit
        Port map (
            clk => clk,
            MemRead => IMR,
            MemWrite => IMW,
            Address => PC,
            DataIn => INST,
            DataOut => IF_Instr
        );

    -- PC and IF/ID register
    process (clk, reset)
    begin
        if reset = '1' then
            PC <= 0;
            IF_ID_Valid <= '0';
            IF_ID_Instr <= (others => '0');
            IF_ID_PC <= 0;
        elsif clk'event and clk = '1' then
            if Flush = '1' then
                -- taken branch: jump, and drop the instruction fetched after it
                PC <= EX_Target;
                IF_ID_Valid <= '0';
                IF_ID_Instr <= (others => '0');
            elsif Stall = '0' and UopHold = '0' then
                PC <= (PC + 2) mod PC_range;
                IF_ID_Valid <= '1';
                IF_ID_Instr <= IF_Instr;
                IF_ID_PC <= PC;
            end if;
            -- on a stall, or while ADD-ST issues its micro-ops,
            -- PC and IF/ID keep their values
        end if;
    end process;

    ------------------------------------------------------------------
    -- ID : decode and read registers
    ------------------------------------------------------------------
    ID_OpCode <= IF_ID_Instr(15 downto 12);
    ID_R1     <= '0' & IF_ID_Instr(11 downto 8);
    ID_R2     <= '0' & IF_ID_Instr(7 downto 4);
    ID_R3     <= '0' & IF_ID_Instr(3 downto 0);
    -- 8-bit immediate sign-extended to register width
    ID_Imm    <= std_logic_vector(resize(signed(IF_ID_Instr(7 downto 0)), RegBits));

    Control_Unit_Unit: entity work.Control_Unit
        Port map (
            OpCode => ID_OpCode,
            Z => EX_Zero,
			S => EX_Sign,
			RegWrite => CU_RegWrite,
            MemRead => CU_MemRead,
            MemWrite => CU_MemWrite,
            ALUSrc => CU_ALUSrc,
            Branch => CU_Branch,
            ALUOp => CU_ALUOp,
			MemToReg => CU_MemToReg,
			Reg2Loc => CU_Reg2Loc
        );

    ID_IsAddSt <= '1' when IF_ID_Valid = '1' and ID_OpCode = "0100" else '0';
    -- Keep ADD-ST in ID until its last micro-op is issued
    UopHold    <= '1' when ID_IsAddSt = '1' and UopStep /= 2 else '0';

    -- Normal instructions: same register selection as the single-cycle CPU.
    -- ADD-ST [ADDR], RX: one micro-op per cycle, using the hidden register T
    --   step 0:  LD  T <- Mem[ADDR]
    --   step 1:  ADD T <- T + RX        (waits 1 cycle for the LD: load-use)
    --   step 2:  ST  Mem[ADDR] <- T
    process (CU_RegWrite, CU_MemRead, CU_MemWrite, CU_ALUSrc, CU_Branch, CU_Reg2Loc,
             CU_MemToReg, CU_ALUOp, ID_R1, ID_R2, ID_R3, ID_IsAddSt, UopStep)
    begin
        ID_RegWrite <= CU_RegWrite;
        ID_MemRead  <= CU_MemRead;
        ID_MemWrite <= CU_MemWrite;
        ID_ALUSrc   <= CU_ALUSrc;
        ID_Branch   <= CU_Branch;
        ID_MemToReg <= CU_MemToReg;
        ID_ALUOp    <= CU_ALUOp;
        ID_AbsAddr  <= '0';
        ID_StoreReg <= R1_ADDR;                 -- ST stores R1
        if CU_ALUSrc = '1' then                 -- ADDI/LD/ST use IR(11..8)
            ID_Rs1 <= ID_R1;
        else
            ID_Rs1 <= ID_R2;
        end if;
        if CU_Reg2Loc = '1' then
            ID_Rs2 <= ID_R1;
        else
            ID_Rs2 <= ID_R3;
        end if;
        if CU_MemToReg = '1' then               -- LD always loads into R1
            ID_WriteReg <= R1_ADDR;
        else
            ID_WriteReg <= ID_R1;
        end if;

        if ID_IsAddSt = '1' then
            ID_Branch   <= '0';
            ID_Rs1      <= T_ADDR;
            ID_Rs2      <= ID_R1;               -- RX
            ID_WriteReg <= T_ADDR;
            ID_ALUOp    <= "0000";              -- ADD
            case UopStep is
                when 0 =>                       -- LD T <- Mem[ADDR]
                    ID_RegWrite <= '1';
                    ID_MemRead  <= '1';
                    ID_MemWrite <= '0';
                    ID_MemToReg <= '1';
                    ID_ALUSrc   <= '1';
                    ID_AbsAddr  <= '1';
                when 1 =>                       -- ADD T <- T + RX
                    ID_RegWrite <= '1';
                    ID_MemRead  <= '0';
                    ID_MemWrite <= '0';
                    ID_MemToReg <= '0';
                    ID_ALUSrc   <= '0';
                when others =>                  -- ST Mem[ADDR] <- T
                    ID_RegWrite <= '0';
                    ID_MemRead  <= '0';
                    ID_MemWrite <= '1';
                    ID_MemToReg <= '0';
                    ID_ALUSrc   <= '1';
                    ID_AbsAddr  <= '1';
                    ID_StoreReg <= T_ADDR;
            end case;
        end if;
    end process;

    -- Micro-op step counter
    process (clk, reset)
    begin
        if reset = '1' then
            UopStep <= 0;
        elsif clk'event and clk = '1' then
            if Flush = '1' then
                UopStep <= 0;                   -- ADD-ST was on the wrong path
            elsif Stall = '0' and ID_IsAddSt = '1' then
                if UopStep = 2 then
                    UopStep <= 0;
                else
                    UopStep <= UopStep + 1;
                end if;
            end if;
        end if;
    end process;

    -- 32 registers: R0-R15 for programs, R16 = T
    Register_Bank_Unit: entity work.Register_Bank
        Generic map (
            RegBits => RegBits,
            Regs_in_bit => Reg_Addr_Bits
        )
        Port map (
            clk => clk,
            RegWrite => MEM_WB_RegWrite,
            ReadReg1 => ID_Rs1,
            ReadReg2 => ID_Rs2,
            WriteReg => MEM_WB_WriteReg,
            WriteData => WB_WriteData,
            ReadData1 => RF_RD1,
            ReadData2 => RF_RD2,
            R1_Out => RF_R1
        );

    -- WB bypass: the register file is written at the end of this cycle,
    -- so pass the value being written straight through to ID
    ID_RD1   <= WB_WriteData when MEM_WB_RegWrite = '1' and MEM_WB_WriteReg = ID_Rs1 else RF_RD1;
    ID_RD2   <= WB_WriteData when MEM_WB_RegWrite = '1' and MEM_WB_WriteReg = ID_Rs2 else RF_RD2;
    ID_R1Val <= WB_WriteData when MEM_WB_RegWrite = '1' and MEM_WB_WriteReg = R1_ADDR else RF_R1;
    -- Value to store: R1 for ST, T for the last ADD-ST micro-op (T is read as Rs1)
    ID_StoreVal <= ID_RD1 when ID_IsAddSt = '1' else ID_R1Val;

    -- Load-use hazard: a load is in EX and the instruction in ID needs its result
    -- (as operand A, as register operand B, or as the value to store)
    Stall <= '1' when ID_EX_MemRead = '1' and IF_ID_Valid = '1' and
                      (ID_Rs1 = ID_EX_WriteReg or
                       (ID_ALUSrc = '0' and ID_Rs2 = ID_EX_WriteReg) or
                       (ID_MemWrite = '1' and ID_StoreReg = ID_EX_WriteReg))
             else '0';

    -- ID/EX register
    process (clk, reset)
    begin
        if reset = '1' then
            ID_EX_RegWrite <= '0';
            ID_EX_MemRead <= '0';
            ID_EX_MemWrite <= '0';
            ID_EX_ALUSrc <= '0';
            ID_EX_Branch <= '0';
            ID_EX_MemToReg <= '0';
            ID_EX_AbsAddr <= '0';
            ID_EX_ALUOp <= "0000";
        elsif clk'event and clk = '1' then
            if Flush = '1' or Stall = '1' or IF_ID_Valid = '0' then
                -- insert a bubble: an instruction that changes nothing
                ID_EX_RegWrite <= '0';
                ID_EX_MemRead <= '0';
                ID_EX_MemWrite <= '0';
                ID_EX_ALUSrc <= '0';
                ID_EX_Branch <= '0';
                ID_EX_MemToReg <= '0';
                ID_EX_AbsAddr <= '0';
                ID_EX_ALUOp <= "0000";
            else
                ID_EX_RegWrite <= ID_RegWrite;
                ID_EX_MemRead <= ID_MemRead;
                ID_EX_MemWrite <= ID_MemWrite;
                ID_EX_ALUSrc <= ID_ALUSrc;
                ID_EX_Branch <= ID_Branch;
                ID_EX_MemToReg <= ID_MemToReg;
                ID_EX_AbsAddr <= ID_AbsAddr;
                ID_EX_ALUOp <= ID_ALUOp;
            end if;
            ID_EX_Rs1 <= ID_Rs1;
            ID_EX_Rs2 <= ID_Rs2;
            ID_EX_WriteReg <= ID_WriteReg;
            ID_EX_StoreReg <= ID_StoreReg;
            ID_EX_RD1 <= ID_RD1;
            ID_EX_RD2 <= ID_RD2;
            ID_EX_StoreVal <= ID_StoreVal;
            ID_EX_Imm <= ID_Imm;
            ID_EX_PC <= IF_ID_PC;
        end if;
    end process;

    ------------------------------------------------------------------
    -- EX : forward operands, run the ALU, decide branches
    ------------------------------------------------------------------
    -- A load in MEM has no data yet (only its address), so never forward it;
    -- the load-use stall guarantees nobody needs it from there
    EX_Fwd_WE <= EX_MEM_RegWrite and not EX_MEM_MemToReg;

    EX_A <= forward(ID_EX_Rs1, ID_EX_RD1,
                    EX_Fwd_WE, EX_MEM_WriteReg, EX_MEM_ALUResult,
                    MEM_WB_RegWrite, MEM_WB_WriteReg, WB_WriteData);
    EX_RD2 <= forward(ID_EX_Rs2, ID_EX_RD2,
                      EX_Fwd_WE, EX_MEM_WriteReg, EX_MEM_ALUResult,
                      MEM_WB_RegWrite, MEM_WB_WriteReg, WB_WriteData);
    EX_StoreData <= forward(ID_EX_StoreReg, ID_EX_StoreVal,
                            EX_Fwd_WE, EX_MEM_WriteReg, EX_MEM_ALUResult,
                            MEM_WB_RegWrite, MEM_WB_WriteReg, WB_WriteData);

    EX_B <= ID_EX_Imm when ID_EX_ALUSrc = '1' else EX_RD2;

    ALU_Unit: entity work.ALU
        Generic map (
            RegBits => RegBits
        )
        Port map (
			clk => clk,
            A => EX_A,
            B => EX_B,
            OpCode => ID_EX_ALUOp,
            Result => EX_ALUResult,
            Carry => EX_Carry,
            Zero => EX_Zero,
            Sign => EX_Sign,
			UnB => EX_UnB
        );

    -- ADD-ST's memory micro-ops use ADDR itself as the address
    EX_Result <= ID_EX_Imm when ID_EX_AbsAddr = '1' else EX_ALUResult;

    -- BR always jumps, BZ/BNZ jump when the ALU says so (UnB).
    -- Target is relative to the branch itself, like PC_Unit.
    Flush <= ID_EX_Branch or EX_UnB;
    EX_Target <= (ID_EX_PC + to_integer(unsigned(ID_EX_Imm(7 downto 0))) * 2) mod PC_range;

    -- EX/MEM register
    process (clk, reset)
    begin
        if reset = '1' then
            EX_MEM_RegWrite <= '0';
            EX_MEM_MemRead <= '0';
            EX_MEM_MemWrite <= '0';
            EX_MEM_MemToReg <= '0';
        elsif clk'event and clk = '1' then
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemToReg <= ID_EX_MemToReg;
            EX_MEM_WriteReg <= ID_EX_WriteReg;
            EX_MEM_ALUResult <= EX_Result;
            EX_MEM_StoreData <= EX_StoreData;
            EX_MEM_PC <= ID_EX_PC;
        end if;
    end process;

    ------------------------------------------------------------------
    -- MEM : data memory access
    ------------------------------------------------------------------
    Memory_Unit_Unit: entity work.Memory_Unit
        Generic map (
            AddrWidth => MemAddrWidth,
            DataWidth => RegBits
        )
        Port map (
            clk => clk,
            MemRead => EX_MEM_MemRead,
            MemWrite => EX_MEM_MemWrite,
            Address => EX_MEM_ALUResult(MemAddrWidth - 1 downto 0),
            DataIn => EX_MEM_StoreData,
            DataOut => MEM_DataOut
        );

    -- MEM/WB register
    process (clk, reset)
    begin
        if reset = '1' then
            MEM_WB_RegWrite <= '0';
            MEM_WB_MemToReg <= '0';
        elsif clk'event and clk = '1' then
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_MemToReg <= EX_MEM_MemToReg;
            MEM_WB_WriteReg <= EX_MEM_WriteReg;
            MEM_WB_ALUResult <= EX_MEM_ALUResult;
            MEM_WB_MemData <= MEM_DataOut;
            MEM_WB_PC <= EX_MEM_PC;
        end if;
    end process;

    ------------------------------------------------------------------
    -- WB : write the result back (the register file writes on the clock edge)
    ------------------------------------------------------------------
    WB_WriteData <= MEM_WB_MemData when MEM_WB_MemToReg = '1' else MEM_WB_ALUResult;

end Behavioral;
