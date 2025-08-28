---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- Idecode module (implements the register file for the MIPS computer)
-- Handles instruction decoding, register file operations, and branch/jump logic
---------------------------------------------------------------------------------------------

LIBRARY IEEE; 		
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

---------------------------------------------------------------------------------------------
-- ENTITY DECLARATION
-- Instruction Decode stage: decodes instructions, manages register file, handles branches
---------------------------------------------------------------------------------------------
ENTITY Idecode IS
	generic(
		DATA_BUS_WIDTH : integer 	:= 32;  -- 32-bit data width
		PC_WIDTH : integer 			:= 10;  -- Program counter width
		NEXT_PC_WIDTH : integer 	:= 8    -- Next PC width (word-aligned)
	);
	PORT(	
		-- Clock and Reset
		clk_i,rst_i,rst_prev_stage	: IN 	STD_LOGIC;
		
		-- Input from Instruction Fetch Stage
		curr_PC_i			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		PC_PLUS_FOUR_i		: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		
		-- Inputs from Memory/Writeback Stages
		dtcm_data_rd_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Memory read data
		alu_result_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- ALU result
		write_reg_addr_i 	: IN	STD_LOGIC_VECTOR( 4 DOWNTO 0 );               -- Register write address
		write_reg_data_i	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0 ); -- Register write data
		RegWrite_WB_i		: IN 	STD_LOGIC;                                     -- Register write enable
		
		-- Pipeline Control
		stall_i				: IN 	STD_LOGIC;  -- Stall signal
		
		-- Data Forwarding Inputs
		ForwardRT_Dec_i		: IN 	STD_LOGIC;
		ForwardRS_Dec_i		: IN 	STD_LOGIC;
		RT_from_mem_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		RS_from_mem_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		-- Control Signals Input (from Control Unit)
		RegDst_ctrl_i		: IN 	STD_LOGIC;                           -- Register destination select
		ALUSrc_ctrl_i 		: IN 	STD_LOGIC;                           -- ALU source select
		ALUOp_ctrl_i		: IN 	STD_LOGIC_VECTOR(5 DOWNTO 0);       -- ALU operation
		MemtOReg_ctrl_i 	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);       -- Memory to register select
		MemRead_ctrl_i 		: IN 	STD_LOGIC;                           -- Memory read enable
		MemWrite_ctrl_i		: IN 	STD_LOGIC;                           -- Memory write enable
		RegWrite_ctrl_i 	: IN 	STD_LOGIC;                           -- Register write enable
		Branch_ctrl_i 		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);       -- Branch control
		jump_i				: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);       -- Jump control
		
		-- Control Signals Output (to Execute Stage)
		RegDst_ctrl_o		: OUT 	STD_LOGIC;
		ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
		ALUOp_ctrl_o		: OUT 	STD_LOGIC_VECTOR(5 DOWNTO 0);
		MemtOReg_ctrl_o 	: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		MemRead_ctrl_o 		: OUT 	STD_LOGIC;
		MemWrite_ctrl_o		: OUT 	STD_LOGIC;
		RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
		
		-- Branch/Jump Control Outputs (to Instruction Fetch)
		pc_select_o			: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);           -- PC source select
		JumpAddress_o   	: OUT 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0); -- Jump target
		BranchAddress_o 	: OUT 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0); -- Branch target
		
		-- Data Outputs (to Execute Stage)
		read_data1_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- RS register data
		read_data2_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- RT register data
		RegisterS_o			: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);                -- RS register address
		RegisterT_o			: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);                -- RT register address
		RegisterD_o			: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);                -- RD register address
		sign_extend_o 		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- Sign-extended immediate
		PC_PLUS_FOUR_o		: OUT 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- PC+4 value
		
		-- Debug/Monitoring Outputs
		curr_pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- Current PC (async)
		curr_inst_o			: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- Current instruction (async)
		synch_curr_pc_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- Current PC (sync)
		synch_curr_inst_o	: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)  -- Current instruction (sync)
	);
END Idecode;

---------------------------------------------------------------------------------------------
-- ARCHITECTURE IMPLEMENTATION
---------------------------------------------------------------------------------------------
ARCHITECTURE behavior OF Idecode IS

	-- Register File: 32 registers x 32 bits each
	TYPE register_file IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL RF_q					: register_file;  -- Register file storage

	-- Instruction Field Extraction
	SIGNAL rs_register_w		: STD_LOGIC_VECTOR( 4 DOWNTO 0 );  -- RS field [25:21]
	SIGNAL rt_register_w		: STD_LOGIC_VECTOR( 4 DOWNTO 0 );  -- RT field [20:16]
	SIGNAL rd_register_w		: STD_LOGIC_VECTOR( 4 DOWNTO 0 );  -- RD field [15:11]
	SIGNAL imm_value_w			: STD_LOGIC_VECTOR( 15 DOWNTO 0 ); -- Immediate field [15:0]
	
	-- Branch Logic
	SIGNAL BEQ					: STD_LOGIC;  -- Branch equal comparison result
	
	-- Control Signal Temporaries (for stall handling)
	SIGNAL RegWrite_ctrl_i_temp : STD_LOGIC;
	SIGNAL MemtOReg_ctrl_i_temp : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL MemRead_ctrl_i_temp 	: STD_LOGIC;
	SIGNAL MemWrite_ctrl_i_temp	: STD_LOGIC;
	SIGNAL RegDst_ctrl_i_temp	: STD_LOGIC;
	SIGNAL ALUSrc_ctrl_i_temp 	: STD_LOGIC;
	SIGNAL ALUOp_ctrl_i_temp	: STD_LOGIC_VECTOR(5 DOWNTO 0);
	
	-- Data Path Temporaries
	SIGNAL read_data1_o_temp	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL read_data2_o_temp	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL RegisterS_o_temp		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL RegisterT_o_temp		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL RegisterD_o_temp		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL sign_extend_o_temp 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL stall_temp			: STD_LOGIC;  -- Registered stall signal

BEGIN
	---------------------------------------------------------------------------------------------
	-- INSTRUCTION FIELD EXTRACTION
	-- Break down 32-bit instruction into component fields
	---------------------------------------------------------------------------------------------
	rs_register_w 			<= instruction_i(25 DOWNTO 21);  -- Source register 1
   	rt_register_w 			<= instruction_i(20 DOWNTO 16);  -- Source register 2 / destination
   	rd_register_w			<= instruction_i(15 DOWNTO 11);  -- Destination register
   	imm_value_w 			<= instruction_i(15 DOWNTO 0);   -- 16-bit immediate value
	
	---------------------------------------------------------------------------------------------
	-- REGISTER FILE READ OPERATIONS WITH FORWARDING
	-- Read two registers simultaneously, with data forwarding support
	---------------------------------------------------------------------------------------------
	-- Read Register 1 (RS) with forwarding
	read_data1_o_temp <= RF_q(CONV_INTEGER(rs_register_w)) WHEN ForwardRS_Dec_i = '0' ELSE RS_from_mem_i;
	
	-- Read Register 2 (RT) with forwarding		 
	read_data2_o_temp <= RF_q(CONV_INTEGER(rt_register_w)) WHEN ForwardRT_Dec_i = '0' ELSE RT_from_mem_i;
	
	---------------------------------------------------------------------------------------------
	-- SIGN EXTENSION
	-- Extend 16-bit immediate to 32 bits (sign-extended)
	---------------------------------------------------------------------------------------------
    sign_extend_o_temp <= 	X"0000" & imm_value_w WHEN imm_value_w(15) = '0' ELSE  -- Positive: zero extend
						X"FFFF" & imm_value_w;                                    -- Negative: sign extend

	---------------------------------------------------------------------------------------------
	-- REGISTER FILE WRITE PROCESS
	-- Write to register file on falling edge when RegWrite is enabled
	---------------------------------------------------------------------------------------------
	process(clk_i,rst_i)
	begin
		if (rst_i='1') then
			-- Initialize all registers to 0 on reset
			FOR i IN 0 TO 31 LOOP
				RF_q(i) <= CONV_STD_LOGIC_VECTOR(0,32);
			END LOOP;
		elsif (clk_i'event and clk_i='0') then  -- Write on falling edge
			-- Write to register if enabled and not writing to register 0 (hardwired to 0)
			if (RegWrite_WB_i = '1' AND write_reg_addr_i /= 0) then
				RF_q(CONV_INTEGER(write_reg_addr_i)) <= write_reg_data_i;
			end if;
		end if;
	end process;

	---------------------------------------------------------------------------------------------
	-- BRANCH AND JUMP ADDRESS CALCULATION
	---------------------------------------------------------------------------------------------
	-- Branch Address: PC+4 + sign_extended_offset
	BranchAddress_o <= PC_PLUS_FOUR_i(PC_WIDTH-1 DOWNTO 2) + instruction_i(NEXT_PC_WIDTH-1 DOWNTO 0);
	
	-- Jump Address: depends on jump type
	JumpAddress_o	<=   instruction_i(NEXT_PC_WIDTH-1 DOWNTO 0) WHEN jump_i = "01" ELSE      -- J/JAL: immediate
						 read_data1_o_temp(NEXT_PC_WIDTH + 1 DOWNTO 2) WHEN jump_i = "10" ELSE -- JR/JALR: register
						X"00";                                                                   -- No jump
	
	-- PC Source Selection Logic
	pc_select_o(0)	<=  '0' WHEN jump_i = "00" ELSE '1';  -- Jump control bit
	
	-- Branch Comparison and Control
	BEQ				<=  '1' WHEN (read_data1_o_temp = read_data2_o_temp) ELSE '0';  -- Equal comparison
	pc_select_o(1)  <=  '1' WHEN (((BEQ = '1') AND (Branch_ctrl_i = "00")) OR           -- BEQ taken
							       ((BEQ = '0') AND (Branch_ctrl_i = "01"))) ELSE '0';   -- BNE taken
	
	---------------------------------------------------------------------------------------------
	-- INSTRUCTION FIELD OUTPUTS
	-- Pass instruction fields to next pipeline stage
	---------------------------------------------------------------------------------------------
	RegisterD_o_temp <= instruction_i(15 DOWNTO 11);  -- RD field
	RegisterT_o_temp <= instruction_i(20 DOWNTO 16);  -- RT field
	RegisterS_o_temp <= instruction_i(25 DOWNTO 21);  -- RS field
	
	---------------------------------------------------------------------------------------------
	-- STALL HANDLING
	-- Register stall signal to fix bubble timing
	---------------------------------------------------------------------------------------------
	stall_proc : PROCESS(clk_i)
	BEGIN
		IF (rising_edge(clk_i)) THEN
			stall_temp <= stall_i;  -- Delay stall by one cycle
		END IF;
	END PROCESS;

	---------------------------------------------------------------------------------------------
	-- CONTROL SIGNAL STALL MULTIPLEXING
	-- Clear control signals during stall to insert NOPs
	---------------------------------------------------------------------------------------------
	RegDst_ctrl_i_temp 		<= RegDst_ctrl_i 	WHEN stall_i = '0' ELSE '0';	
	ALUSrc_ctrl_i_temp 		<= ALUSrc_ctrl_i 	WHEN stall_i = '0' ELSE '0';
	ALUOp_ctrl_i_temp  		<= ALUOp_ctrl_i 	WHEN stall_i = '0' ELSE (OTHERS => '0');
	MemtOReg_ctrl_i_temp  	<= MemtOReg_ctrl_i 	WHEN stall_i = '0' ELSE (OTHERS => '0');
	MemRead_ctrl_i_temp  	<= MemRead_ctrl_i  	WHEN stall_i = '0' ELSE '0';
	MemWrite_ctrl_i_temp  	<= MemWrite_ctrl_i 	WHEN stall_i = '0' ELSE '0';
	RegWrite_ctrl_i_temp	<= RegWrite_ctrl_i 	WHEN stall_i = '0' ELSE '0';
	
	---------------------------------------------------------------------------------------------
	-- PIPELINE REGISTER PROCESS
	-- Register all outputs on rising edge for pipeline synchronization
	---------------------------------------------------------------------------------------------
	piping_proccess : PROCESS(clk_i)
	BEGIN
		IF (rising_edge(clk_i)) THEN
			-- Control Signals to Execute Stage
			RegDst_ctrl_o		<= RegDst_ctrl_i_temp;	
			ALUSrc_ctrl_o 	    <= ALUSrc_ctrl_i_temp; 	
			ALUOp_ctrl_o		<= ALUOp_ctrl_i_temp;	
			MemtOReg_ctrl_o		<= MemtOReg_ctrl_i_temp;
			MemRead_ctrl_o 		<= MemRead_ctrl_i_temp;
			MemWrite_ctrl_o		<= MemWrite_ctrl_i_temp;
			RegWrite_ctrl_o		<= RegWrite_ctrl_i_temp;
			
			-- Data Outputs
			read_data1_o		<= read_data1_o_temp;   -- RS register data
			read_data2_o		<= read_data2_o_temp;   -- RT register data
			RegisterT_o			<= RegisterT_o_temp;    -- RT address
			RegisterD_o			<= RegisterD_o_temp;    -- RD address
			RegisterS_o			<= RegisterS_o_temp;    -- RS address
			sign_extend_o		<= sign_extend_o_temp;  -- Sign-extended immediate
			PC_PLUS_FOUR_o		<= PC_PLUS_FOUR_i;      -- Pass through PC+4
			
			-- Debug/Monitoring (synchronized)
			synch_curr_pc_o 	<= curr_PC_i;
			synch_curr_inst_o 	<= instruction_i;
		ELSE
			NULL;
		END IF;
	END PROCESS;
	
	---------------------------------------------------------------------------------------------
	-- ASYNCHRONOUS OUTPUTS
	-- Direct connections for immediate visibility
	---------------------------------------------------------------------------------------------
	curr_pc_o 	<= curr_PC_i;     -- Current PC (not registered)
	curr_inst_o <= instruction_i; -- Current instruction (not registered)

END behavior;