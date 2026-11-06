library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

	-- Add your library and packages declaration here ...

entity alu_tb is
	generic(RegBits : integer:=16);
end alu_tb;

architecture TB_ARCHITECTURE of alu_tb is
	-- Component declaration of the tested unit
	component ALU
	generic(RegBits : integer:=16);
	port(
		clk : in STD_LOGIC;
		A : in STD_LOGIC_VECTOR(RegBits-1 downto 0);
		B : in STD_LOGIC_VECTOR(RegBits-1 downto 0);
		OpCode : in STD_LOGIC_VECTOR(3 downto 0);
		Result : out STD_LOGIC_VECTOR(RegBits-1 downto 0);
		Carry : out STD_LOGIC;
		Zero : out STD_LOGIC;
		Sign : out STD_LOGIC;
		UnB  : out  Std_logic);
	end component;

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal clk : STD_LOGIC:='0';
	signal A : STD_LOGIC_VECTOR(RegBits-1 downto 0);
	signal B : STD_LOGIC_VECTOR(RegBits-1 downto 0);
	signal OpCode : STD_LOGIC_VECTOR(3 downto 0);
	-- Observed signals - signals mapped to the output ports of tested entity
	signal Result : STD_LOGIC_VECTOR(RegBits-1 downto 0);
	signal Carry : STD_LOGIC;
	signal Zero : STD_LOGIC;
	signal Sign : STD_LOGIC;
	signal UnB  : STD_LOGIC ;

	-- Add your code here ...

begin

	-- Unit Under Test port map
	UUT : ALU
		generic map (
			RegBits => RegBits
		)
		port map (
			clk => clk,
			A => A,
			B => B,
			OpCode => OpCode,
			Result => Result,
			Carry => Carry,
			Zero => Zero,
			Sign => Sign,
			UnB => UnB
		);

	-- Add your stimulus here ...
	clk <= not clk after 2 ns;
	-- clk <= '1' after 2ns , '0' after 4ns;
	 process
		 procedure check(exp_res : std_logic_vector(RegBits-1 downto 0);
						 exp_c, exp_z, exp_s : std_logic; name : string) is
		 begin
			 assert Result = exp_res and Carry = exp_c and Zero = exp_z and Sign = exp_s
				 report name & " failed" severity error;
		 end procedure;
	 begin
		 A<= x"FFFF";
		 B<= x"0001";
		 Opcode <= "0000"; -- ADD : overflow -> 0, carry
		 wait for 4 ns;
		 check(x"0000", '1', '1', '0', "ADD");

		 A<= x"0001";
		 B<= x"0002";
		 Opcode <= "0001"; -- SUB : 1 - 2 = -1, borrow
		 wait for 4 ns;
		 check(x"FFFF", '1', '0', '1', "SUB");

		 A<= x"1234";
		 B<= x"0000";
		 Opcode <= "0011"; -- MOV : Rd <- A
		 wait for 4 ns;
		 check(x"1234", '0', '0', '0', "MOV");

		 A<= x"FFFE";
		 B<= x"0003";
		 Opcode <= "0100"; -- ADD-ST : Mem[ADDR] + RX, with carry
		 wait for 4 ns;
		 check(x"0001", '1', '0', '0', "ADD-ST");

		 A<= "1010101010101010";
		 B<= "0101010101010101";
		 Opcode <= "0101"; -- XOR
		 wait for 4 ns;
		 check(x"FFFF", '0', '0', '1', "XOR");

		 A<= "1010101010101010";
		 B<= "0101010101010101";
		 Opcode <= "0110"; -- AND
		 wait for 4 ns;
		 check(x"0000", '0', '1', '0', "AND");

		 A<= "0010101010101010";
		 B<= "0101010101010100";
		 Opcode <= "0111"; -- OR
		 wait for 4 ns;
		 check(x"7FFE", '0', '0', '0', "OR");

		 A<= x"0000";
		 Opcode <= "1000"; -- NOT
		 wait for 4 ns;
		 check(x"FFFF", '0', '0', '1', "NOT");

		 A<= x"8001";
		 Opcode <= "1001"; -- SHL : MSB shifted out into carry
		 wait for 4 ns;
		 check(x"0002", '1', '0', '0', "SHL");

		 A<= x"0010";
		 Opcode <= "1010"; -- SHR
		 wait for 4 ns;
		 check(x"0008", '0', '0', '0', "SHR");

		 A<= x"0003";
		 B<= x"0005";
		 Opcode <= "1011"; -- LD : address = base + offset
		 wait for 4 ns;
		 assert Result = x"0008" report "LD address failed" severity error;

		 B<= x"0000";
		 Opcode <= "1110"; -- BZ taken
		 wait for 4 ns;
		 assert UnB = '1' report "BZ failed" severity error;

		 Opcode <= "1111"; -- BNZ not taken
		 wait for 4 ns;
		 assert UnB = '0' report "BNZ failed" severity error;

		 report "ALU test finished";
		 wait;
	 end process;
end TB_ARCHITECTURE;

configuration TESTBENCH_FOR_alu of alu_tb is
	for TB_ARCHITECTURE
		for UUT : alu
			use entity work.alu(behavioral);
		end for;
	end for;
end TESTBENCH_FOR_alu;

