library IEEE;
use IEEE.STD_LOGIC_1164.all;  
use IEEE.numeric_std.all; 

entity CPU is
    Port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
		IMR : in std_logic;
		IMW : in Std_logic;
		INST : in Std_logic_vector(15 downto 0)
    );
end CPU;

architecture Behavioral of CPU is
    constant RegBits     : integer := 16;    -- data / register width
    constant Regs_in_bit : integer := 4;     -- 16 registers -> 4-bit register fields
    constant MemAddrWidth: integer := 4;     -- data memory address width
    constant PC_range    : integer := 2**9;  -- instruction memory size in bytes

    signal PC     				  : integer range 0 to PC_range - 1 := 0;
    signal IR      				  : STD_LOGIC_VECTOR(15 downto 0);
    signal OpCode   			  : STD_LOGIC_VECTOR(3 downto 0);
    signal R1, R2, R3 ,Reg_1_Read, Reg_2_Read, Write_Reg : STD_LOGIC_VECTOR(Regs_in_bit - 1 downto 0);
    signal xyz                    : STD_LOGIC_VECTOR(7 downto 0);
    signal Imm ,RD1,RD2,RD_2,Write_Data      : STD_LOGIC_VECTOR(RegBits - 1 downto 0);
    signal ALUResult, MemDataOut  : STD_LOGIC_VECTOR(RegBits - 1 downto 0);
    signal Carry, Zero, Sign      : STD_LOGIC;
	signal RegWrite    			  : STD_LOGIC;
    signal MemRead     			  : STD_LOGIC;
    signal MemWrite    			  : STD_LOGIC;
    signal ALUSrc      			  : STD_LOGIC;
    signal Branch,UnB      		  : STD_LOGIC;
    signal ALUOp       			  : STD_LOGIC_VECTOR(3 downto 0);
	signal Reg2Loc	   			  : STD_LOGIC; 
	signal MemToReg	   			  : STD_LOGIC;
    signal R1_Mem : STD_LOGIC_VECTOR(RegBits - 1 downto 0);
    signal AddSt                  : STD_LOGIC;
    signal ALU_A, Mem_DataIn      : STD_LOGIC_VECTOR(RegBits - 1 downto 0);
    signal Mem_Address            : STD_LOGIC_VECTOR(MemAddrWidth - 1 downto 0);

begin
	process (IR)
    begin	   
        R1     <= IR(11 downto 8);  -- 4 bits
        R2     <= IR(7 downto 4);   -- 4 bits
        R3     <= IR(3 downto 0);   -- 4 bits
        OpCode <= IR(15 downto 12); -- 4-bit opcode
        xyz    <= IR(7 downto 0);   -- full lower byte
        
    end process;   
	-- 8-bit immediate sign-extended to register width (so ADDI R1, -1 works)
	Imm <= std_logic_vector(resize(signed(xyz), RegBits));
	-- I-type (ADDI/LD/ST) keep their source/base register in IR(11..8),
	-- because IR(7..0) is the immediate
	Reg_1_Read <= R1 when ALUSrc = '1' else R2;
	-- LD always loads into R1 (implicit destination)
	Write_Reg <= "0001" when MemToReg = '1' else R1;
	-- ADD-ST [ADDR], RX is the only instruction that reads and writes memory:
	-- Mem[ADDR] goes into the ALU, RX is added, and the sum is written back
	-- to Mem[ADDR] at the clock edge
	AddSt       <= MemRead and MemWrite;
	ALU_A       <= MemDataOut when AddSt = '1' else RD1;
	Mem_Address <= xyz(MemAddrWidth - 1 downto 0) when AddSt = '1' else ALUResult(MemAddrWidth - 1 downto 0);
	Mem_DataIn  <= ALUResult when AddSt = '1' else R1_Mem;
	process (R1,R3,Reg2Loc)
    begin
		if Reg2Loc = '1' then
			Reg_2_Read <= R1;
		else
			Reg_2_Read <= R3;
		end if;
    end process; 
	process (MemToReg,MemDataOut,ALUResult)
    begin
		if MemToReg = '1' then
			Write_Data <= MemDataOut;
		else
			Write_Data <= ALUResult;
		end if;
    end process; 
	process (ALUSrc,Imm,RD2)
    begin
		if ALUSrc = '1' then
			RD_2 <= Imm;
		else
			RD_2 <= RD2;
		end if;
    end process;
    -- Control Unit
    Control_Unit_Unit: entity work.Control_Unit
        Port map (
            OpCode => OpCode,
            Z => Zero,
			S => Sign,
			RegWrite => RegWrite,
            MemRead => MemRead,
            MemWrite => MemWrite,
            ALUSrc => ALUSrc,
            Branch => Branch,
            ALUOp => ALUOp,
			MemToReg => MemToReg,
			Reg2Loc => Reg2Loc
        );

    -- Register Bank
    Register_Bank_Unit: entity work.Register_Bank
        Generic map (
            RegBits => RegBits,
            Regs_in_bit => Regs_in_bit
        )
        Port map (
            clk => clk,
            RegWrite => RegWrite,
            ReadReg1 => Reg_1_Read,
            ReadReg2 => Reg_2_Read,
            WriteReg => Write_Reg,
            WriteData => Write_Data,
            ReadData1 => RD1,
            ReadData2 => RD2,
            R1_Out => R1_Mem
        );

    -- ALU
    ALU_Unit: entity work.ALU
        Generic map (
            RegBits => RegBits
        )
        Port map ( 
			clk => clk,
            B => RD_2,
            A => ALU_A,
            OpCode => ALUOp,          
            Result => ALUResult,
            Carry => Carry,
            Zero => Zero,
            Sign => Sign,
			UnB => UnB
        );

    -- Memory Unit
    Memory_Unit_Unit: entity work.Memory_Unit
        Generic map (
            AddrWidth => MemAddrWidth,
            DataWidth => RegBits
        )
        Port map (
            clk => clk,
            MemRead => MemRead,
            MemWrite => MemWrite,
            Address => Mem_Address,
            DataIn => Mem_DataIn,
            DataOut => MemDataOut
        );
	-- Instruction_Memory_Unit
    Instruction_Memory_Unit_Unit: entity work.Instruction_Memory_Unit
        Port map (
            clk => clk,
            MemRead => IMR,
            MemWrite => IMW,
            Address => PC,
            DataIn => INST,
            DataOut => IR
        );

    -- Program Counter Unit
    PC_Unit_Unit: entity work.PC_Unit
        Generic map (
            PC_range => PC_range
        )
        Port map (
            clk => clk,
            reset => reset,
			Ubranch => UnB,
            branch => Branch,
            offset => xyz,
            PC => PC
        );

end Behavioral;