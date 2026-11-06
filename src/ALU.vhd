library IEEE;
use IEEE.STD_LOGIC_1164.ALL;    
use IEEE.numeric_std.all; 	  
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity ALU is
	generic(RegBits : integer:=16);

    Port (	 
		clk       : in Std_logic;
        A         : in  STD_LOGIC_VECTOR(RegBits - 1 downto 0);
        B         : in  STD_LOGIC_VECTOR(RegBits - 1 downto 0);
        OpCode    : in  STD_LOGIC_VECTOR(3 downto 0);
        Result    : out  STD_LOGIC_VECTOR(RegBits - 1 downto 0);
        Carry	  : out  STD_LOGIC;		   
        Zero      : out  STD_LOGIC;   	  
		Sign      : out  Std_logic;
		UnB       : out  Std_logic
    );
end ALU;

architecture Behavioral of ALU is 
signal res : STD_LOGIC_VECTOR(RegBits downto 0);
begin 

    process (A, B, OpCode) 
	variable Temp_Result : STD_LOGIC_VECTOR(RegBits downto 0);  
    begin		   
		Temp_Result := (others => '0');
		UnB <= '0';
        case OpCode is
            when "0000" => -- ADD
                Temp_Result := ('0' & A) + ('0' & B);
            when "0001" => -- SUB
                Temp_Result := ('0' & A) - ('0' & B);
            when "0010" => -- ADDI
                Temp_Result := ('0' & A) + ("0" & B);
			when "0011" => -- MOV (source register is in the Rs slot -> A)
				Temp_Result := ('0' & A);
            when "0100" => -- ADD-ST : Mem[ADDR] + RX
				Temp_Result := ('0' & A) + ('0' & B);
            when "0101" => -- XOR
                Temp_Result := '0' & (A xor B);
            when "0110" => -- AND
                Temp_Result := '0' & (A and B);
			when "0111" => -- Or	  
                Temp_Result := '0' & (A OR B);
			when "1000" =>  -- Not
                Temp_Result := '0' & (not A);
            when "1001" => -- SHL (shifted-out bit goes to Carry)
                Temp_Result := A & '0';
            when "1010" => -- SHR
				Temp_Result := '0' & ('0' & A(RegBits-1 downto 1));
			when "1011" => -- LD  
				Temp_Result := ('0' & A) + ("0" & B);

			when "1100" => -- ST	  
				Temp_Result := ('0' & A) + ("0" & B);

			-- ALU doesnt need this part
			-- when "1101" => -- Br  	
			-- 	UnB <= '1';
			when "1110" => -- BZ  	
				if to_integer(unsigned(B(RegBits-1 downto 0))) = 0 then
					UnB <= '1';
				else
					UnB <= '0';   
				end if;
			when "1111" => -- BNZ  
				if to_integer(unsigned(B(RegBits-1 downto 0))) = 0 then
					UnB <= '0';
				else
					UnB <= '1';   
				end if;
            when others =>
                Temp_Result := (others => '0');
		end case;
		Result <= Temp_Result(RegBits-1 downto 0);
		--report "Temp Result = " & integer'image(to_integer(unsigned(Temp_Result)));
		res <= temp_result;

		if (to_integer(unsigned(Opcode)) < 11) then  
			Carry <= Temp_Result(RegBits);
			Sign <= Temp_Result(RegBits-1);
			-- report "Result = " & integer'image(to_integer(unsigned(res(7 downto 0))));

			if to_integer(unsigned(Temp_Result(RegBits-1 downto 0))) = 0 then
				
				Zero <= '1';	   
			else
				Zero <= '0';
			end if;
		else 
			Carry <= 'Z';
			Sign <= 'Z';
			Zero <= 'Z' ;
		end if;	 
		
    end process;


end Behavioral;
