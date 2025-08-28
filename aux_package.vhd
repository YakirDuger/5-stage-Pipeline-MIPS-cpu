---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
USE work.cond_comilation_package.all;


package aux_package is

--------------------------------------------------------------------------------------------
	COMPONENT top_pipeline is
		generic( 
			DATA_BUS_WIDTH     : integer   := 32;
			PC_WIDTH           : integer   := 10;
			NEXT_PC_WIDTH      : integer   := 8;
			FUNCT_WIDTH        : integer   := 6;
			CLK_CNT_WIDTH      : integer   := 16;
			INST_CNT_WIDTH     : integer   := 16
		);            
		PORT(   
			-- Inputs
			rst_i              : IN    STD_LOGIC;
			clk_i              : IN    STD_LOGIC; 
			BPADDR_i           : IN    STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- (break point address)
			
			-- Outputs (as shown in Figure 8)
			--CLKCNT_o           : OUT   STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
			--INSTCNT_o          : OUT   STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0);
			
			-- Pipeline stage PC tracking
			IFpc_o             : OUT   STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			IDpc_o             : OUT   STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EXpc_o             : OUT   STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEMpc_o            : OUT   STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			WBpc_o             : OUT   STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			
			-- Pipeline stage instruction tracking
			IFinstruction_o    : OUT   STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IDinstruction_o    : OUT   STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EXinstruction_o    : OUT   STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEMinstruction_o   : OUT   STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			WBinstruction_o    : OUT   STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			
			-- Performance counters
			STRIGGER_o         : OUT   STD_LOGIC;
			FHCNT_o            : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0);
			STCNT_o            : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0)
			--mclk_cnt_o			:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
			--inst_cnt_o 			:OUT	STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0)
		);
	end COMPONENT;
---------------------------------------------------------------------------------------------
	COMPONENT MIPS IS
	generic( 
			WORD_GRANULARITY : boolean 	:= G_WORD_GRANULARITY;
	       		 MODELSIM : integer 			:= G_MODELSIM;
			DATA_BUS_WIDTH : integer 	:= 32;
			ITCM_ADDR_WIDTH : integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH : integer 	:= G_ADDRWIDTH;
			PC_WIDTH : integer 			:= 10;
			NEXT_PC_WIDTH : integer 	:= 8;
			FUNCT_WIDTH : integer 		:= 6;
			DATA_WORDS_NUM : integer 	:= G_DATA_WORDS_NUM;
			CLK_CNT_WIDTH : integer 	:= 16;
			INST_CNT_WIDTH : integer 	:= 16
	);
	PORT(	rst_i		 		:IN	STD_LOGIC;
			clk_i				:IN	STD_LOGIC; 
			PBADD_i				:IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- Needs to have 2 additional zeros added to the LSB by TOP
			-- Output important signals to pins for easy display in SignalTap
			pc_o				:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			alu_result_o 		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data1_o 		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o 		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			write_data_o		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			instruction_top_o	:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			Branch_ctrl_o		:OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			Zero_o				:OUT 	STD_LOGIC; 
			MemWrite_ctrl_o		:OUT 	STD_LOGIC;
			RegWrite_ctrl_o		:OUT 	STD_LOGIC;
			-- Outputs for the TOP e
			IF_PC_o				:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			ID_PC_o             :OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EX_PC_o             :OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEM_PC_o            :OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			WB_PC_o             :OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			IF_inst_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ID_inst_o           :OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EX_inst_o           :OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEM_inst_o          :OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			WB_inst_o           :OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			STRIGGER_o			:OUT	STD_LOGIC;
			FH_cnt_o            :OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			ST_cnt_o            :OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			mclk_cnt_o			:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
			inst_cnt_o 			:OUT	STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0)
	);		
END COMPONENT;
---------------------------------------------------------  
	COMPONENT control IS
	PORT( 	
			clk_i 				: IN 	STD_LOGIC;
			opcode_i, funct_i	: IN 	STD_LOGIC_VECTOR(5 DOWNTO 0);
			RegDst_ctrl_o 		: OUT 	STD_LOGIC;
			ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
			MemtOReg_ctrl_o 	: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
			MemRead_ctrl_o 		: OUT 	STD_LOGIC;
			MemWrite_ctrl_o	 	: OUT 	STD_LOGIC;
			Branch_ctrl_o 		: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUOp_ctrl_o	 	: OUT 	STD_LOGIC_VECTOR(5 DOWNTO 0);
			jump_o				: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0)
		);
	END COMPONENT;
---------------------------------------------------------	

	COMPONENT dmemory IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			DTCM_ADDR_WIDTH : integer := 8;
			WORDS_NUM : integer := 256;
			PC_WIDTH  : integer := 10
		);
		PORT(	clk_i,rst_i			: IN 	STD_LOGIC;
				dtcm_addr_i 		: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
				dtcm_data_wr_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				MemRead_ctrl_i  	: IN 	STD_LOGIC;
				MemWrite_ctrl_i 	: IN 	STD_LOGIC;
				pc_plus4_i 			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				-- For TOP
				curr_PC_i			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				curr_inst_i			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- Pass the ALU result onwards
				ALU_res_i			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				ALU_res_o			: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- Instruction
				RegisterRes_i		: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				RegisterRes_o		: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				-- Passed onwards via WB --------
				MemtOReg_ctrl_i 	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0); 
				MemtOReg_ctrl_o 	: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0); 
				RegWrite_ctrl_i 	: IN 	STD_LOGIC;
				RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
				pc_plus4_o 			: OUT 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				-- For TOP
				-- Non synchronics Outputs
				curr_pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				curr_inst_o			: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				synch_curr_pc_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				synch_curr_inst_o	: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- DTCM Output
				dtcm_data_rd_o 		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- Non syncrhonic output
				dtcm_data_rd_not_syncronic_o 	: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;
---------------------------------------------------------		
	COMPONENT  Execute IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			FUNCT_WIDTH : integer := 6;
			PC_WIDTH : integer := 10
		);
		PORT(	read_data1_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				read_data2_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				sign_extend_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				funct_i 			: IN 	STD_LOGIC_VECTOR(6-1 DOWNTO 0);
				ALUOp_ctrl_i 		: IN 	STD_LOGIC_VECTOR(5 DOWNTO 0);
				ALUSrc_ctrl_i 		: IN 	STD_LOGIC;
				clk_i				: IN 	STD_LOGIC; -- new
				-- For TOP
				curr_PC_i			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				curr_inst_i			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				----------
				pc_plus4_i 			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				ForwardRS			: IN 	STD_LOGIC_VECTOR (1 DOWNTO 0);
				ForwardRT			: IN 	STD_LOGIC_VECTOR (1 DOWNTO 0);
				RegForwardMEM		: IN 	STD_LOGIC_VECTOR (DATA_BUS_WIDTH - 1 DOWNTO 0);
				RegForwarWB			: IN 	STD_LOGIC_VECTOR (DATA_BUS_WIDTH - 1 DOWNTO 0);
				-- New inputs from piping_proccess
				-- Register Address
				RegDst_ctrl_i		: IN 	STD_LOGIC;
				RegisterS_i			: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				RegisterT_i			: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				RegisterD_i			: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				RegisterRes_o		: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				-- Passed onwards via WB --------
				MemtOReg_ctrl_i 	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0); 
				MemtOReg_ctrl_o 	: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0); 
				RegWrite_ctrl_i 	: IN 	STD_LOGIC;
				RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
				-- For Top
				-- Non synchronics Outputs
				curr_pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				curr_inst_o			: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				synch_curr_pc_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				synch_curr_inst_o	: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- Passed onwards via MEM --------
				MemRead_ctrl_i 		: IN 	STD_LOGIC; 
				MemWrite_ctrl_i		: IN 	STD_LOGIC;
				MemRead_ctrl_o 		: OUT 	STD_LOGIC; 
				MemWrite_ctrl_o		: OUT 	STD_LOGIC;
				DTCM_data_o			: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH - 1 DOWNTO 0);
				pc_plus4_o			: OUT 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				alu_res_o 			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;
---------------------------------------------------------		
	COMPONENT Idecode IS
		generic(
			DATA_BUS_WIDTH : integer 	:= 32;
			PC_WIDTH : integer 			:= 10;
			NEXT_PC_WIDTH : integer 	:= 8

		);
		PORT(	clk_i,rst_i,rst_prev_stage	: IN 	STD_LOGIC;
				-- FOr TOP
				curr_PC_i			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				instruction_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				----------
				dtcm_data_rd_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				alu_result_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				stall_i				: IN 	STD_LOGIC;
				PC_PLUS_FOUR_i		: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				-- Forwarding inputs
				ForwardRT_Dec_i		: IN 	STD_LOGIC;
				ForwardRS_Dec_i		: IN 	STD_LOGIC;
				RT_from_mem_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				RS_from_mem_i		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- New inputs from passing MUXs to other stages
				write_reg_addr_i 	: IN	STD_LOGIC_VECTOR( 4 DOWNTO 0 );
				write_reg_data_i	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0 );
				-- Inputs from control
				-- Passed onwards via EXE --------
				RegDst_ctrl_i		: IN 	STD_LOGIC;
				ALUSrc_ctrl_i 		: IN 	STD_LOGIC;
				ALUOp_ctrl_i		: IN 	STD_LOGIC_VECTOR(5 DOWNTO 0);
				RegDst_ctrl_o		: OUT 	STD_LOGIC;
				ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
				ALUOp_ctrl_o		: OUT 	STD_LOGIC_VECTOR(5 DOWNTO 0);
				-- Passed onwards via WB --------
				MemtOReg_ctrl_i 	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0); 
				MemtOReg_ctrl_o 	: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0); 
				-- Passed onwards via MEM --------
				MemRead_ctrl_i 		: IN 	STD_LOGIC; 
				MemWrite_ctrl_i		: IN 	STD_LOGIC;
				MemRead_ctrl_o 		: OUT 	STD_LOGIC; 
				MemWrite_ctrl_o		: OUT 	STD_LOGIC;
				-- END --------------------------
				RegWrite_ctrl_i 	: IN 	STD_LOGIC;
				RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
				RegWrite_WB_i		: IN 	STD_LOGIC;
				Branch_ctrl_i 		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
				jump_i				: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
				-- Outputs
				-- From ID back to Ifetch
				pc_select_o			: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
				JumpAddress_o   	: OUT 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);
				BranchAddress_o 	: OUT 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);
				-- Data Out From ID onwards
				read_data1_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				read_data2_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- For TOP
				-- Non synchronics Outputs
				curr_pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				curr_inst_o			: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				synch_curr_pc_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				synch_curr_inst_o	: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				-- Instruction onwards
				RegisterS_o			: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				RegisterT_o			: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				RegisterD_o			: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
				PC_PLUS_FOUR_o		: OUT 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				sign_extend_o 		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)		 
		);
	END COMPONENT;
---------------------------------------------------------		
	COMPONENT Ifetch IS
		generic(
			WORD_GRANULARITY : boolean 	:= False;
			DATA_BUS_WIDTH : integer 	:= 32;
			PC_WIDTH : integer 		:= 10;
			NEXT_PC_WIDTH : integer 	:= 8; -- NEXT_PC_WIDTH = PC_WIDTH-2
			ITCM_ADDR_WIDTH : integer 	:= 8;
			WORDS_NUM : integer 		:= 256;
			INST_CNT_WIDTH : integer 	:= 16
		);
		PORT(	
			clk_i, rst_i 	: IN 	STD_LOGIC;
			rst_o		: OUT 	STD_LOGIC;
			-- new inputs from pipelining
			flush_i			: IN 	STD_LOGIC;
			stall_i			: IN 	STD_LOGIC;
			pc_select_i		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			JumpAddress_i   : IN 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);
			BranchAddress_i : IN 	STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);
			-- Outputs
			pc_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			-- Non synchronics -------------------
			curr_pc_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			curr_inst_o		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			--------------------------------------
			pc_plus4_o		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o 	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			inst_cnt_o 		: OUT	STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0)	
		);
	END COMPONENT;
---------------------------------------------------------
	COMPONENT Shifter IS 
		generic (
			n : integer := 8;
			k : integer := 3;
			m : integer := 4
		);
		port (
			x,y           : in  std_logic_vector(n-1 downto 0);
			ALUFN       : in std_logic_vector(2 downto 0);
			res : out std_logic_vector(n-1 downto 0);
			cout: out std_logic
		);
	end COMPONENT;
---------------------------------------------------------
	COMPONENT PLL port(
	    areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0     		: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC );
    END COMPONENT;
---------------------------------------------------------	
	COMPONENT ForwordingUnit IS
	PORT( 
			clk					: IN STD_LOGIC;
			RegisterRdMEM		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegisterRdWB		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegisterRsEX		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegisterRtEX		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegisterRsDEC		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegisterRtDEC		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegisteWriteMem		: IN STD_LOGIC;
			RegisteWriteWB		: IN STD_LOGIC;
			ForwardRS_Exe		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			ForwardRT_Exe		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			ForwardRT_Dec		: OUT STD_LOGIC;
			ForwardRS_Dec		: OUT STD_LOGIC
		);
	END COMPONENT;
----------------------------------------------------------
	COMPONENT Hazard_Detection_unit IS
	PORT( 	
			RegRtEx							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegRtID							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegRdEx							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegRsID							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
			Reg_writeEx						:	IN 		STD_LOGIC;
			Branch_cond						: 	IN 		STD_LOGIC;
			RegDstEx						: 	IN 		STD_LOGIC;  -- NEW: 1=R-type (rd dest), 0=I-type (rt dest)
			stall_cnt						: 	OUT 	STD_LOGIC;
			stall_pc						: 	OUT   	STD_LOGIC
		);
	END COMPONENT;
-----------------------------------------------------------

end aux_package;

