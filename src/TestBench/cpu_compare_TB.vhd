library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

-- Runs the single-cycle CPU (reference) and the pipelined CPU side by side on
-- the same program.data. Both must make exactly the same register writes and
-- memory writes in the same order; only the timing may differ.
-- Needs VHDL-2008 (--std=08) for the external names (<< signal ... >>).
entity cpu_compare_tb is
	generic(Cycles : integer := 600);
end cpu_compare_tb;

architecture TB_ARCHITECTURE of cpu_compare_tb is
	signal clk   : STD_LOGIC := '0';
	signal reset : STD_LOGIC := '1';
	signal IMR   : STD_LOGIC := '1';
	signal IMW   : STD_LOGIC := '0';
	signal INST  : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	signal done  : boolean := false;

	-- One write: register number / memory address, and the value written
	type write_t is record
		addr : integer;
		data : integer;
	end record;
	type write_list is array (0 to Cycles) of write_t;
begin

	SC : entity work.CPU
		port map (clk => clk, reset => reset, IMR => IMR, IMW => IMW, INST => INST);
	PL : entity work.CPU_Pipeline
		port map (clk => clk, reset => reset, IMR => IMR, IMW => IMW, INST => INST);

	clk <= not clk after 4 ns when not done;

	process
		-- single-cycle CPU: everything commits at the clock edge
		alias sc_reg_we   is << signal .cpu_compare_tb.SC.RegWrite   : std_logic >>;
		alias sc_reg_addr is << signal .cpu_compare_tb.SC.Write_Reg  : std_logic_vector(3 downto 0) >>;
		alias sc_reg_data is << signal .cpu_compare_tb.SC.Write_Data : std_logic_vector(15 downto 0) >>;
		alias sc_mem_we   is << signal .cpu_compare_tb.SC.MemWrite   : std_logic >>;
		alias sc_mem_addr is << signal .cpu_compare_tb.SC.Mem_Address : std_logic_vector(3 downto 0) >>;
		alias sc_mem_data is << signal .cpu_compare_tb.SC.Mem_DataIn  : std_logic_vector(15 downto 0) >>;
		-- pipeline: registers commit in WB, memory in MEM.
		-- Its register numbers have 5 bits: R16 is the hidden register T of ADD-ST
		alias pl_reg_we   is << signal .cpu_compare_tb.PL.MEM_WB_RegWrite  : std_logic >>;
		alias pl_reg_addr is << signal .cpu_compare_tb.PL.MEM_WB_WriteReg  : std_logic_vector(4 downto 0) >>;
		alias pl_reg_data is << signal .cpu_compare_tb.PL.WB_WriteData     : std_logic_vector(15 downto 0) >>;
		alias pl_mem_we   is << signal .cpu_compare_tb.PL.EX_MEM_MemWrite  : std_logic >>;
		alias pl_mem_addr is << signal .cpu_compare_tb.PL.EX_MEM_ALUResult : std_logic_vector(15 downto 0) >>;
		alias pl_mem_data is << signal .cpu_compare_tb.PL.EX_MEM_StoreData : std_logic_vector(15 downto 0) >>;

		variable sc_regs, pl_regs, sc_mems, pl_mems : write_list;
		variable n_sc_regs, n_pl_regs, n_sc_mems, n_pl_mems : integer := 0;
		variable errors : integer := 0;

		procedure compare(name : string; ref, dut : write_list; n_ref, n_dut : integer) is
			variable n : integer;
		begin
			-- the pipeline is behind, so compare the part both have done
			n := n_dut;
			if n_ref < n then
				n := n_ref;
			end if;
			for i in 0 to n - 1 loop
				if ref(i) /= dut(i) then
					errors := errors + 1;
					if errors <= 10 then
						report name & " write #" & integer'image(i) &
							": single-cycle [" & integer'image(ref(i).addr) & "] <= " & integer'image(ref(i).data) &
							", pipeline ["      & integer'image(dut(i).addr) & "] <= " & integer'image(dut(i).data)
							severity error;
					end if;
				end if;
			end loop;
			-- a pipeline that commits (almost) nothing must not pass
			if n_dut < n_ref / 2 then
				errors := errors + 1;
				report name & ": pipeline made only " & integer'image(n_dut) & " writes, single-cycle made " &
					integer'image(n_ref) severity error;
			end if;
			report name & " writes compared: " & integer'image(n) &
				" (single-cycle " & integer'image(n_ref) & ", pipeline " & integer'image(n_dut) & ")";
		end procedure;
	begin
		reset <= '1';
		wait for 2 ns;
		reset <= '0';

		for i in 1 to Cycles loop
			-- at the rising edge the signals still show what is being written now
			wait until clk = '1';
			if sc_reg_we = '1' then
				sc_regs(n_sc_regs) := (to_integer(unsigned(sc_reg_addr)), to_integer(unsigned(sc_reg_data)));
				n_sc_regs := n_sc_regs + 1;
			end if;
			if sc_mem_we = '1' then
				sc_mems(n_sc_mems) := (to_integer(unsigned(sc_mem_addr(3 downto 0))), to_integer(unsigned(sc_mem_data)));
				n_sc_mems := n_sc_mems + 1;
			end if;
			if pl_reg_we = '1' and pl_reg_addr(4) = '0' then   -- T is internal, not compared
				pl_regs(n_pl_regs) := (to_integer(unsigned(pl_reg_addr)), to_integer(unsigned(pl_reg_data)));
				n_pl_regs := n_pl_regs + 1;
			end if;
			if pl_mem_we = '1' then
				pl_mems(n_pl_mems) := (to_integer(unsigned(pl_mem_addr(3 downto 0))), to_integer(unsigned(pl_mem_data)));
				n_pl_mems := n_pl_mems + 1;
			end if;
		end loop;

		compare("Register", sc_regs, pl_regs, n_sc_regs, n_pl_regs);
		compare("Memory",   sc_mems, pl_mems, n_sc_mems, n_pl_mems);

		assert errors = 0 report "FAIL: pipeline differs from single-cycle CPU" severity failure;
		report "PASS: pipeline matches single-cycle CPU";
		done <= true;
		wait;
	end process;

end TB_ARCHITECTURE;
