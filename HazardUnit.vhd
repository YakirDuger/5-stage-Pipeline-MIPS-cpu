--------------- Top Level Structural Model for MIPS Processor Core
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.numeric_std.all;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY HazardUnit IS
	PORT( 
		MemtoReg_EX, MemtoReg_MEM	 		 : IN STD_LOGIC;
		WriteReg_EX, WriteReg_MEM, WriteReg_WB : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  -- rt and rd mux output
		RegRs_ID, RegRt_ID 					 : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegRs_EX, RegRt_EX					 : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_RegWr, MEM_RegWr, WB_RegWr		 : IN  STD_LOGIC;
		BranchBeq_ID, BranchBne_ID, Jump_ID	 : IN STD_LOGIC;
		Stall_IF, Stall_ID, Flush_EX 	 	 : OUT STD_LOGIC;
		ForwardA, ForwardB				     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		ForwardA_Branch, ForwardB_Branch	 : OUT STD_LOGIC
		);
END 	HazardUnit;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF HazardUnit IS
SIGNAL LwStall, BranchStall : BOOLEAN;
BEGIN
----------- Stall and Flush -----------------------	
	-- FIX: writes to $zero never need an interlock.
	LwStall <= MemtoReg_EX = '1' AND RegRt_EX /= "00000"
	           AND ( RegRt_EX = RegRs_ID OR RegRt_EX = RegRt_ID );
	-- FIX: the second term used to test BranchBeq_ID only, so a bne whose
	-- operand came from a load two instructions back was never stalled.
	-- ForwardA/B_Branch then handed the ID comparator ALU_Result_MEM, which
	-- for a load is the ADDRESS, not the loaded data, and the branch resolved
	-- against the wrong value. Writes to $zero are excluded as well.
	BranchStall <=
		-- operand produced by the instruction currently in EX
		( (BranchBeq_ID = '1' OR BranchBne_ID = '1')
		  AND EX_RegWr = '1' AND WriteReg_EX /= "00000"
		  AND (WriteReg_EX = RegRs_ID OR WriteReg_EX = RegRt_ID) )
		OR
		-- operand produced by a LOAD currently in MEM (data not ready yet)
		( (BranchBeq_ID = '1' OR BranchBne_ID = '1')
		  AND MemtoReg_MEM = '1' AND WriteReg_MEM /= "00000"
		  AND (WriteReg_MEM = RegRs_ID OR WriteReg_MEM = RegRt_ID) );

	-- (the old commented-out BranchBneStall attempt is folded in above; it
	--  used /= where it needed =, so it would have stalled on almost
	--  every branch)
	
	Stall_IF <= '1' WHEN (LwStall OR BranchStall) ELSE '0';
	Stall_ID <= '1' WHEN (LwStall OR BranchStall) ELSE '0';
	--Flush_EX <= '1' WHEN (LwStall OR BranchStall OR Jump_ID = '1') ELSE '0';
	Flush_EX <= '1' WHEN (LwStall OR BranchStall) ELSE '0';

----------- Forwarding -----------------------	
    --------------------- Register Forwarding -----------------------
	-- EX Hazard
	ForwardA <= "10" WHEN ((MEM_RegWr = '1') AND (WriteReg_MEM /= "00000") AND (WriteReg_MEM = RegRs_EX)) ELSE  -- EX Hazard take from MEM
				"01" WHEN (WB_RegWr = '1' AND WriteReg_WB /= "00000" AND (NOT (MEM_RegWr = '1' AND WriteReg_MEM /= "00000" AND (WriteReg_MEM = RegRs_EX))) AND WriteReg_WB = RegRs_EX)	ELSE -- MEM Hazard take from WB
				"00";

	ForwardB <= "10" WHEN (MEM_RegWr = '1' AND WriteReg_MEM /= "00000" AND WriteReg_MEM = RegRt_EX) ELSE  -- EX Hazard take from MEM
				"01" WHEN (WB_RegWr = '1' AND WriteReg_WB /= "00000" AND (NOT (MEM_RegWr = '1' AND WriteReg_MEM /= "00000" AND (WriteReg_MEM = RegRt_EX))) AND WriteReg_WB = RegRt_EX)	ELSE -- MEM Hazard take from WB
				"00";	

	-------------- Branch Forwarding --------------------
	ForwardA_Branch <= '1' WHEN ((RegRs_ID /= "00000") AND (RegRs_ID = WriteReg_MEM) AND MEM_RegWr = '1') ELSE '0';
	
	ForwardB_Branch <= '1' WHEN ((RegRt_ID /= "00000") AND (RegRt_ID = WriteReg_MEM) AND MEM_RegWr = '1') ELSE '0';
	

END structure;