---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- Ifetch module (provides the PC and instruction 
-- memory for the MIPS computer)
---------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

---------------------------------------------------------------------------------------------
-- ENTITY DECLARATION
-- This module handles instruction fetch for a MIPS pipeline processor
-- It includes PC management, instruction memory interface, and pipeline control
---------------------------------------------------------------------------------------------
ENTITY Ifetch IS
	generic(
		WORD_GRANULARITY : boolean 	:= False;  -- Memory addressing: False=byte addressable, True=word addressable
		DATA_BUS_WIDTH : integer 	:= 32;     -- Width of data/instruction bus (32-bit MIPS)
		PC_WIDTH : integer 		:= 10;     -- Program Counter width in bits
		NEXT_PC_WIDTH : integer 	:= 8;      -- Next PC width (PC_WIDTH-2, excludes lower 2 bits)
		ITCM_ADDR_WIDTH : integer 	:= 8;      -- Instruction Tightly Coupled Memory address width
		WORDS_NUM : integer 		:= 256;    -- Number of words in instruction memory
		INST_CNT_WIDTH : integer 	:= 16      -- Instruction counter width for performance monitoring
	);
	PORT(	
		-- Clock and Reset
		clk_i, rst_i 	: IN 	STD_LOGIC;     -- Input clock and reset
		rst_o		: OUT 	STD_LOGIC;     -- Output reset (pipelined)
		
		-- Pipeline Control Inputs
		flush_i			: IN 	STD_LOGIC;     -- Pipeline flush signal (clear pipeline)
		stall_i			: IN 	STD_LOGIC;     -- Pipeline stall signal (freeze PC)
		pc_select_i		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);  -- PC source select: 00=PC+4, 01=Jump, 10=Branch
		
		-- Jump and Branch Target Addresses
		JumpAddress_i   : IN 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);  -- Jump target address
		BranchAddress_i : IN 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);  -- Branch target address
		
		-- Synchronized Outputs (registered on clock edge)
		pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- Current PC (pipelined)
		pc_plus4_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- PC+4 (pipelined)
		instruction_o 	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- Fetched instruction (pipelined)
		
		-- Asynchronous Outputs (combinational, not registered)
		curr_pc_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- Current PC (immediate)
		curr_inst_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- Current instruction (immediate)
		
		-- Performance Counter
		inst_cnt_o 		: OUT	STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0)  -- Instruction count for performance monitoring
	);
END Ifetch;

---------------------------------------------------------------------------------------------
-- ARCHITECTURE IMPLEMENTATION
---------------------------------------------------------------------------------------------
ARCHITECTURE behavior OF Ifetch IS
	-- Program Counter and Address Generation Signals
	SIGNAL pc_q				  : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);        -- Current PC register
	SIGNAL pc_plus4_r 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);        -- PC+4 calculation result
	SIGNAL itcm_addr_w 			: STD_LOGIC_VECTOR(ITCM_ADDR_WIDTH-1 DOWNTO 0);  -- Instruction memory address
	SIGNAL next_pc_w  			: STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);     -- Next PC value (word-aligned)
	
	-- Reset and Control Signals
	SIGNAL rst_flag_q			: STD_LOGIC;  -- Registered reset flag for synchronization
	
	-- Performance Monitoring Signals
	SIGNAL inst_cnt_q 			: STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0);  -- Instruction counter register
	SIGNAL pc_prev_q			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);        -- Previous PC for stall detection
	
	-- Pipeline Stage Temporary Signals (before pipeline registers)
	SIGNAL pc_o_temp 			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);         -- Temporary PC output
	SIGNAL pc_plus4_o_temp 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);         -- Temporary PC+4 output
	SIGNAL instruction_o_temp 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);   -- Temporary instruction output
	SIGNAL inst_cnt_o_temp 		: STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0);   -- Temporary instruction count
	
	-- Memory Interface Signal
	SIGNAL memory_clk			: STD_LOGIC;  -- Inverted clock for memory timing

BEGIN
	---------------------------------------------------------------------------------------------
	-- MEMORY CLOCK GENERATION
	-- Use inverted clock for memory to meet setup/hold timing requirements
	---------------------------------------------------------------------------------------------
	memory_clk <= not(clk_i);
 
	---------------------------------------------------------------------------------------------
	-- NEXT PC MULTIPLEXER
	-- Selects the next PC value based on control signals and pipeline state
	-- Priority: Reset > Stall > Jump > Branch > Sequential (PC+4)
	---------------------------------------------------------------------------------------------
	next_pc_w  <= 	(others => '0') WHEN rst_flag_q = '1' ELSE                    -- Reset: PC = 0
					pc_q(PC_WIDTH-1 DOWNTO 2) WHEN stall_i = '1' ELSE            -- Stall: Keep current PC
					JumpAddress_i WHEN pc_select_i = "01" ELSE                    -- Jump: Use jump target
					BranchAddress_i WHEN pc_select_i = "10" ELSE                  -- Branch: Use branch target
					pc_plus4_r(NEXT_PC_WIDTH+1 DOWNTO 2);                        -- Sequential: PC+4

	---------------------------------------------------------------------------------------------
	-- INSTRUCTION MEMORY INSTANCE
	-- ROM implementation using Altera's altsyncram megafunction
	-- Stores the program instructions to be fetched
	---------------------------------------------------------------------------------------------
	inst_memory: altsyncram
	GENERIC MAP(
		operation_mode => "ROM",                                                   -- Read-only memory
		width_a => DATA_BUS_WIDTH,                                                -- 32-bit data width
		widthad_a => ITCM_ADDR_WIDTH,                                            -- Address width
		numwords_a => WORDS_NUM,                                                 -- Number of memory words
		lpm_hint => "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",            -- Enable runtime modification
		lpm_type => "altsyncram",                                                -- Altera syncram type
		outdata_reg_a => "UNREGISTERED",                                         -- No output register (combinational)
		init_file => "D:\LAB5\SW\SW\EX1\bin\ITCM.hex",                         -- Memory initialization file
		intended_device_family => "Cyclone"                                      -- Target FPGA family
	)
	PORT MAP (
		clock0     => memory_clk,      -- Memory clock (inverted system clock)
		address_a  => itcm_addr_w,     -- Memory address input
		q_a 	   => instruction_o_temp -- Memory data output
	);
	
	---------------------------------------------------------------------------------------------
	-- PC WORD ALIGNMENT
	-- MIPS instructions are word-aligned, so lower 2 bits of PC are always "00"
	---------------------------------------------------------------------------------------------
	pc_q(1 DOWNTO 0) 	<= "00";
	
	---------------------------------------------------------------------------------------------
	-- MEMORY ADDRESS GENERATION
	-- Convert PC to memory address based on addressing granularity
	---------------------------------------------------------------------------------------------
	G1: 
	if (WORD_GRANULARITY = True) generate 		-- Word-addressable memory (each address = 1 word)
		itcm_addr_w <= next_pc_w;
	elsif (WORD_GRANULARITY = False) generate 	-- Byte-addressable memory (each address = 1 byte)
		itcm_addr_w <= next_pc_w & "00";        -- Multiply by 4 to get byte address
	end generate;
		
	---------------------------------------------------------------------------------------------
	-- PC+4 CALCULATION
	-- Increment PC by 4 bytes (1 word) for sequential instruction fetch
	---------------------------------------------------------------------------------------------
	pc_plus4_r( 1 DOWNTO 0 )  		 <= "00";                                    -- Keep word alignment
   	pc_plus4_r(PC_WIDTH-1 DOWNTO 2)  <= pc_q(PC_WIDTH-1 DOWNTO 2) + 1;         -- Increment word address
											
	---------------------------------------------------------------------------------------------
	-- RESET FLAG SYNCHRONIZATION
	-- Register the reset signal to synchronize it with the clock domain
	---------------------------------------------------------------------------------------------
	process (clk_i)
	BEGIN
		IF(clk_i'EVENT  AND clk_i='1') THEN
			rst_flag_q <= rst_i;  -- Synchronize reset with rising edge
		end if;
	end process;
	
	---------------------------------------------------------------------------------------------
	-- PROGRAM COUNTER REGISTER
	-- Main PC register updated on falling edge of clock
	-- Reset to 0 when reset is active, otherwise load next_pc_w
	---------------------------------------------------------------------------------------------
	PROCESS (clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			pc_q(PC_WIDTH-1 DOWNTO 2) <= (OTHERS => '0') ;  -- Asynchronous reset to 0
		ELSIF(clk_i'EVENT  AND clk_i='0') THEN              -- Update on falling edge
			pc_q(PC_WIDTH-1 DOWNTO 2) <= next_pc_w;	     -- Load next PC value
		END IF;
	END PROCESS;

	---------------------------------------------------------------------------------------------
	-- INSTRUCTION PERFORMANCE COUNTER
	-- Counts instructions for performance monitoring and debugging
	---------------------------------------------------------------------------------------------
	
	-- Previous PC Register (for stall detection)
	-- Stores the previous PC value to detect when PC changes
	process (clk_i , rst_i)
	begin
		if rst_i = '1' then
			pc_prev_q	<=	(others	=> '0');      -- Reset previous PC
		elsif falling_edge(clk_i) then
			pc_prev_q	<=	pc_q;                 -- Store current PC as previous
		end if;
	end process;
	
	-- Instruction Counter Register
	-- Increments when PC changes (indicating an instruction was executed)
	process (clk_i , rst_i)
	begin
		if rst_i = '1' then
			inst_cnt_q	<=	(others	=> '0');      -- Reset instruction counter
		elsif rising_edge(clk_i) then
			if pc_prev_q /= pc_q then             -- If PC changed (instruction executed)
				inst_cnt_q	<=	inst_cnt_q + '1'; -- Increment instruction counter
			end if;
		end if;
	end process;

	---------------------------------------------------------------------------------------------
	-- PIPELINE REGISTER STAGE
	-- Registers outputs on rising edge of clock for pipeline synchronization
	-- Handles flush and stall conditions for pipeline control
	---------------------------------------------------------------------------------------------
	piping_proccess : PROCESS(clk_i)
	BEGIN
		IF (rising_edge(clk_i)) THEN
			-- Always pass through the reset signal
			rst_o<=rst_i;
			
			IF (flush_i = '1') THEN                          -- Pipeline flush condition
				-- Clear all pipeline registers to insert bubbles
				pc_o				<=	(OTHERS => '0') ;	 -- Clear PC output
				pc_plus4_o			<=	(OTHERS => '0') ;	 -- Clear PC+4 output
				instruction_o 		<=	(OTHERS => '0') ;	 -- Clear instruction output (NOP)
				--inst_cnt_o 			<=	(OTHERS => '0') ;    -- Don't clear instruction counter
			ELSE                                             -- Normal operation (includes stall handling)
				-- Register the temporary values to pipeline outputs
				pc_o				<=	pc_o_temp ;	         -- Register PC
				pc_plus4_o			<=	pc_plus4_o_temp ;	 -- Register PC+4
				instruction_o 		<=	instruction_o_temp ; -- Register instruction
			END IF;
		ELSE                                             	
			NULL;  -- No action on falling edge
		END IF;
	END PROCESS;

	---------------------------------------------------------------------------------------------
	-- OUTPUT SIGNAL ASSIGNMENTS
	-- Connect internal signals to output ports
	---------------------------------------------------------------------------------------------
	
	-- Performance counter output (always connected, not affected by flush)
	inst_cnt_o 			<= inst_cnt_q + '1';
	
	-- Temporary signals for pipeline register inputs
	pc_o_temp 			<= 	pc_q;              -- Current PC
	pc_plus4_o_temp 	<= 	pc_plus4_r;        -- PC+4 calculation result
	
	-- Asynchronous outputs (not pipelined, immediate values)
	curr_pc_o			<= 	pc_q;              -- Current PC (combinational output)
	curr_inst_o			<= 	instruction_o_temp; -- Current instruction (combinational output)

END behavior;