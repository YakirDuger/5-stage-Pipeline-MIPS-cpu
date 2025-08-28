---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- Top Level Structural Model for MIPS Processor Core
-- Reorganized for better readability and maintainability
---------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE ieee.std_logic_unsigned.all;
USE work.cond_comilation_package.all;
USE work.aux_package.all;

ENTITY MIPS IS
    GENERIC( 
        WORD_GRANULARITY    : boolean   := G_WORD_GRANULARITY;
        MODELSIM           : integer    := G_MODELSIM;
        DATA_BUS_WIDTH     : integer    := 32;
        ITCM_ADDR_WIDTH    : integer    := G_ADDRWIDTH;
        DTCM_ADDR_WIDTH    : integer    := G_ADDRWIDTH;
        PC_WIDTH           : integer    := 10;
        NEXT_PC_WIDTH      : integer    := 8;
        FUNCT_WIDTH        : integer    := 6;
        DATA_WORDS_NUM     : integer    := G_DATA_WORDS_NUM;
        CLK_CNT_WIDTH      : integer    := 16;
        INST_CNT_WIDTH     : integer    := 16
    );
    PORT(	
        -- Clock and Reset
        rst_i                   : IN  STD_LOGIC;
        clk_i                   : IN  STD_LOGIC; 
        PBADD_i                 : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- Breakpoint address
        
        -- Debug Output Signals for SignalTap
        pc_o                    : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        alu_result_o            : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        read_data1_o            : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        read_data2_o            : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        write_data_o            : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        instruction_top_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        Branch_ctrl_o           : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        Zero_o                  : OUT STD_LOGIC; 
        MemWrite_ctrl_o         : OUT STD_LOGIC;
        RegWrite_ctrl_o         : OUT STD_LOGIC;
        
        -- Pipeline Stage Outputs for TOP entity
        IF_PC_o                 : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        ID_PC_o                 : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        EX_PC_o                 : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        MEM_PC_o                : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        WB_PC_o                 : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        IF_inst_o               : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        ID_inst_o               : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        EX_inst_o               : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        MEM_inst_o              : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        WB_inst_o               : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        
        -- Performance Counters
        STRIGGER_o              : OUT STD_LOGIC;
        FH_cnt_o                : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        ST_cnt_o                : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        mclk_cnt_o              : OUT STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
        inst_cnt_o              : OUT STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0)
    );		
END MIPS;

-------------------------------------------------------------------------------------
ARCHITECTURE structure OF MIPS IS

-------------------------------------------------------------------------------------
-- INTERNAL CLOCK SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL master_clk                   : STD_LOGIC;
    SIGNAL master_clk_cnt               : STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

-------------------------------------------------------------------------------------
-- INSTRUCTION FETCH (IF) STAGE SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL if_pc_debug                  : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL if_pc_plus4                  : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL if_instruction               : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL if_instruction_count         : STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0);
    SIGNAL if_curr_pc_to_id             : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL if_reset_to_id               : STD_LOGIC;

-------------------------------------------------------------------------------------
-- INSTRUCTION DECODE (ID) STAGE SIGNALS
-------------------------------------------------------------------------------------
    -- Register File Outputs
    SIGNAL id_read_data1                : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL id_read_data2                : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL id_sign_extend               : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    
    -- Control Signals from Control Unit
    SIGNAL ctrl_reg_dst                 : STD_LOGIC;
    SIGNAL ctrl_alu_src                 : STD_LOGIC;
    SIGNAL ctrl_mem_to_reg              : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL ctrl_reg_write               : STD_LOGIC;
    SIGNAL ctrl_mem_read                : STD_LOGIC;
    SIGNAL ctrl_mem_write               : STD_LOGIC;
    SIGNAL ctrl_branch                  : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL ctrl_alu_op                  : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL ctrl_jump                    : STD_LOGIC_VECTOR(1 DOWNTO 0);
    
    -- Pipeline Control Signals ID to EX
    SIGNAL id_to_ex_reg_dst             : STD_LOGIC;
    SIGNAL id_to_ex_alu_src             : STD_LOGIC;
    SIGNAL id_to_ex_alu_op              : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL id_to_ex_mem_to_reg          : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL id_to_ex_mem_read            : STD_LOGIC;
    SIGNAL id_to_ex_mem_write           : STD_LOGIC;
    SIGNAL id_to_ex_reg_write           : STD_LOGIC;
    
    -- Register Addresses
    SIGNAL id_to_ex_reg_s               : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL id_to_ex_reg_t               : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL id_to_ex_reg_d               : STD_LOGIC_VECTOR(4 DOWNTO 0);
    
    -- Branch and Jump Control
    SIGNAL id_pc_select                 : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL id_jump_address              : STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);
    SIGNAL id_branch_address            : STD_LOGIC_VECTOR(NEXT_PC_WIDTH-1 DOWNTO 0);
    
    -- Pipeline Registers
    SIGNAL id_to_ex_pc_plus4            : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL id_curr_pc_to_ex             : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL id_curr_inst_to_ex           : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

-------------------------------------------------------------------------------------
-- EXECUTE (EX) STAGE SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL ex_alu_result                : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL ex_zero_flag                 : STD_LOGIC;
    SIGNAL ex_write_reg_addr            : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL ex_dtcm_write_data           : STD_LOGIC_VECTOR(31 DOWNTO 0);
    
    -- Pipeline Control Signals EX to MEM
    SIGNAL ex_to_mem_mem_to_reg         : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL ex_to_mem_mem_read           : STD_LOGIC;
    SIGNAL ex_to_mem_mem_write          : STD_LOGIC;
    SIGNAL ex_to_mem_reg_write          : STD_LOGIC;
    
    -- Pipeline Registers
    SIGNAL ex_to_mem_pc_plus4           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL ex_curr_pc_to_mem            : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL ex_curr_inst_to_mem          : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

-------------------------------------------------------------------------------------
-- MEMORY (MEM) STAGE SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL mem_dtcm_read_data           : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL mem_dtcm_read_data_async     : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL mem_alu_result               : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL mem_write_reg_addr           : STD_LOGIC_VECTOR(4 DOWNTO 0);
    
    -- Pipeline Control Signals MEM to WB
    SIGNAL mem_to_wb_mem_to_reg         : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL mem_to_wb_reg_write          : STD_LOGIC;
    
    -- Pipeline Registers
    SIGNAL mem_to_wb_pc_plus4           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL mem_curr_pc_to_wb            : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL mem_curr_inst_to_wb          : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

-------------------------------------------------------------------------------------
-- WRITE BACK (WB) STAGE SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL wb_write_reg_data            : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL wb_write_reg_addr_mux        : STD_LOGIC_VECTOR(4 DOWNTO 0); -- For JAL instruction
    SIGNAL wb_alu_result_feedback       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL wb_dtcm_data_feedback        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

-------------------------------------------------------------------------------------
-- HAZARD DETECTION AND FORWARDING SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL hazard_stall_pc              : STD_LOGIC;
    SIGNAL hazard_stall_cnt             : STD_LOGIC;
    SIGNAL hazard_branch_condition      : STD_LOGIC;
    
    -- Forwarding Control Signals
    SIGNAL forward_rs_to_ex             : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL forward_rt_to_ex             : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL forward_rt_to_id             : STD_LOGIC;
    SIGNAL forward_rs_to_id             : STD_LOGIC;
    SIGNAL forward_mem_to_ex_mux        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

-------------------------------------------------------------------------------------
-- BREAKPOINT AND CONTROL SIGNALS
-------------------------------------------------------------------------------------
    SIGNAL breakpoint_pc                : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL program_run_enable           : STD_LOGIC := '0';
    SIGNAL stall_or_run_control         : STD_LOGIC := '0';
    SIGNAL flush_pipeline               : STD_LOGIC := '0';

-------------------------------------------------------------------------------------
-- PERFORMANCE COUNTERS
-------------------------------------------------------------------------------------
    SIGNAL perf_stall_count             : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL perf_flush_count             : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL perf_inst_count              : STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0);
    SIGNAL flush_pipeline_prev          : STD_LOGIC;  -- Track previous flush state for edge detection

-------------------------------------------------------------------------------------
-- LEGACY SIGNALS (for compatibility)
-------------------------------------------------------------------------------------
    SIGNAL instruction_w                : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL read_data1_w                 : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL read_data2_w                 : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL alu_result_w                 : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL dtcm_data_rd_w               : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL branch_w                     : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL zero_w                       : STD_LOGIC;
    SIGNAL reg_write_w                  : STD_LOGIC;
    SIGNAL mem_write_w                  : STD_LOGIC;
    SIGNAL MemtoReg_w                   : STD_LOGIC_VECTOR(1 DOWNTO 0);

BEGIN

-------------------------------------------------------------------------------------
-- OUTPUT SIGNAL ASSIGNMENTS FOR DEBUG AND MONITORING
-------------------------------------------------------------------------------------
    -- Debug outputs for SignalTap
    instruction_top_o   <= instruction_w;
    alu_result_o        <= alu_result_w;
    read_data1_o        <= read_data1_w;
    read_data2_o        <= read_data2_w;
    write_data_o        <= dtcm_data_rd_w WHEN MemtoReg_w = "01" ELSE alu_result_w;
    Branch_ctrl_o       <= branch_w;
    Zero_o              <= zero_w;
    RegWrite_ctrl_o     <= reg_write_w;
    MemWrite_ctrl_o     <= mem_write_w;	
   
    -- Performance counter outputs
    mclk_cnt_o          <= master_clk_cnt;
    inst_cnt_o          <= perf_inst_count;

    -- Pipeline stage outputs for TOP entity
    WB_PC_o             <= mem_curr_pc_to_wb;
    WB_inst_o           <= mem_curr_inst_to_wb;

-------------------------------------------------------------------------------------
-- CLOCK GENERATION - PLL OR DIRECT CLOCK
-------------------------------------------------------------------------------------
    PLL_GENERATE: 
    if (MODELSIM = 0) generate
        PLL_INST: PLL
        PORT MAP (
            inclk0  => clk_i,
            c0      => master_clk
        );
    else generate
        master_clk <= clk_i;
    end generate;

-------------------------------------------------------------------------------------
-- INSTRUCTION FETCH STAGE
-------------------------------------------------------------------------------------
    INSTRUCTION_FETCH: Ifetch
    GENERIC MAP(
        WORD_GRANULARITY    => WORD_GRANULARITY,
        DATA_BUS_WIDTH      => DATA_BUS_WIDTH, 
        PC_WIDTH            => PC_WIDTH,
        NEXT_PC_WIDTH       => PC_WIDTH - 2,
        ITCM_ADDR_WIDTH     => ITCM_ADDR_WIDTH,
        WORDS_NUM           => DATA_WORDS_NUM,
        INST_CNT_WIDTH      => INST_CNT_WIDTH
    )
    PORT MAP (	
        clk_i               => master_clk,
        rst_i               => rst_i,
        rst_o               => if_reset_to_id,
        
        -- Pipeline control
        flush_i             => '0',  -- Disable actual flush - natural timing handles jumps correctly
        stall_i             => stall_or_run_control,
        pc_select_i         => id_pc_select,
        JumpAddress_i       => id_jump_address,
        BranchAddress_i     => id_branch_address,
        
        -- Outputs      
        curr_pc_o           => IF_PC_o,
        curr_inst_o         => IF_inst_o,
        pc_o                => if_pc_debug,
        pc_plus4_o          => if_pc_plus4,
        instruction_o       => if_instruction,
        inst_cnt_o          => if_instruction_count
    );

-------------------------------------------------------------------------------------
-- INSTRUCTION DECODE STAGE
-------------------------------------------------------------------------------------
    INSTRUCTION_DECODE: Idecode
    GENERIC MAP(
        DATA_BUS_WIDTH      => DATA_BUS_WIDTH,
        PC_WIDTH            => PC_WIDTH
    )
    PORT MAP (	
        clk_i               => master_clk,
        rst_i               => rst_i,
        rst_prev_stage      => if_reset_to_id,
        
        -- Input from IF stage
        curr_PC_i           => if_pc_debug,
        instruction_i       => if_instruction,
        PC_PLUS_FOUR_i      => if_pc_plus4,
        stall_i             => stall_or_run_control,
        
        -- Writeback inputs
        write_reg_addr_i    => wb_write_reg_addr_mux,
        write_reg_data_i    => wb_write_reg_data,
        dtcm_data_rd_i      => wb_dtcm_data_feedback,
        alu_result_i        => wb_alu_result_feedback,
        
        -- Forwarding inputs
        ForwardRT_Dec_i     => forward_rt_to_id,
        ForwardRS_Dec_i     => forward_rs_to_id,
        RT_from_mem_i       => ex_alu_result,
        RS_from_mem_i       => ex_alu_result,
        
        -- Control signals input
        RegDst_ctrl_i       => ctrl_reg_dst,
        ALUSrc_ctrl_i       => ctrl_alu_src,
        ALUOp_ctrl_i        => ctrl_alu_op,
        MemtOReg_ctrl_i     => ctrl_mem_to_reg,
        MemRead_ctrl_i      => ctrl_mem_read,
        MemWrite_ctrl_i     => ctrl_mem_write,
        RegWrite_ctrl_i     => ctrl_reg_write,
        RegWrite_WB_i       => mem_to_wb_reg_write,
        Branch_ctrl_i       => ctrl_branch,
        jump_i              => ctrl_jump,
        
        -- Control signals output to EX stage
        RegDst_ctrl_o       => id_to_ex_reg_dst,
        ALUSrc_ctrl_o       => id_to_ex_alu_src,
        ALUOp_ctrl_o        => id_to_ex_alu_op,
        MemtOReg_ctrl_o     => id_to_ex_mem_to_reg,
        MemRead_ctrl_o      => id_to_ex_mem_read,
        MemWrite_ctrl_o     => id_to_ex_mem_write,
        RegWrite_ctrl_o     => id_to_ex_reg_write,
        
        -- Branch/Jump control back to IF
        pc_select_o         => id_pc_select,
        JumpAddress_o       => id_jump_address,
        BranchAddress_o     => id_branch_address,
        
        -- Data outputs to EX stage
        read_data1_o        => id_read_data1,
        read_data2_o        => id_read_data2,
        sign_extend_o       => id_sign_extend,
        
        -- Register addresses to EX stage
        RegisterS_o         => id_to_ex_reg_s,
        RegisterT_o         => id_to_ex_reg_t,
        RegisterD_o         => id_to_ex_reg_d,
        
        -- Pipeline registers
        PC_PLUS_FOUR_o      => id_to_ex_pc_plus4,
        curr_pc_o           => ID_PC_o,
        curr_inst_o         => ID_inst_o,
        synch_curr_pc_o     => id_curr_pc_to_ex,
        synch_curr_inst_o   => id_curr_inst_to_ex
    );

-------------------------------------------------------------------------------------
-- CONTROL UNIT
-------------------------------------------------------------------------------------
    CONTROL_UNIT: control
    PORT MAP ( 	
        clk_i               => master_clk,
        opcode_i            => if_instruction(31 DOWNTO 26),
        funct_i             => if_instruction(5 DOWNTO 0),
        
        -- Control outputs
        RegDst_ctrl_o       => ctrl_reg_dst,
        ALUSrc_ctrl_o       => ctrl_alu_src,
        MemtoReg_ctrl_o     => ctrl_mem_to_reg,
        RegWrite_ctrl_o     => ctrl_reg_write,
        MemRead_ctrl_o      => ctrl_mem_read,
        MemWrite_ctrl_o     => ctrl_mem_write,
        Branch_ctrl_o       => ctrl_branch,  
        ALUOp_ctrl_o        => ctrl_alu_op,
        jump_o              => ctrl_jump
    );
    
    -- Branch condition for hazard detection
    hazard_branch_condition <= '1' WHEN (ctrl_branch = "00" OR ctrl_branch = "01") ELSE '0';

-------------------------------------------------------------------------------------
-- EXECUTE STAGE
-------------------------------------------------------------------------------------
    EXECUTE_STAGE: Execute
    GENERIC MAP(
        DATA_BUS_WIDTH      => DATA_BUS_WIDTH,
        FUNCT_WIDTH         => FUNCT_WIDTH,
        PC_WIDTH            => PC_WIDTH
    )
    PORT MAP (	
        clk_i               => master_clk,
        
        -- Data inputs from ID stage
        read_data1_i        => id_read_data1,
        read_data2_i        => id_read_data2,
        sign_extend_i       => id_sign_extend,
        funct_i             => id_sign_extend(5 DOWNTO 0),
        pc_plus4_i          => id_to_ex_pc_plus4,
        
        -- Control inputs from ID stage
        ALUOp_ctrl_i        => id_to_ex_alu_op,
        ALUSrc_ctrl_i       => id_to_ex_alu_src,
        RegDst_ctrl_i       => id_to_ex_reg_dst,
        
        -- Register addresses from ID stage
        RegisterS_i         => id_to_ex_reg_s,
        RegisterT_i         => id_to_ex_reg_t,
        RegisterD_i         => id_to_ex_reg_d,
        
        -- Forwarding inputs
        ForwardRS           => forward_rs_to_ex,
        ForwardRT           => forward_rt_to_ex,
        RegForwardMEM       => forward_mem_to_ex_mux,
        RegForwarWB         => wb_write_reg_data,
        
        -- Pipeline control signals
        MemtOReg_ctrl_i     => id_to_ex_mem_to_reg,
        MemRead_ctrl_i      => id_to_ex_mem_read,
        MemWrite_ctrl_i     => id_to_ex_mem_write,
        RegWrite_ctrl_i     => id_to_ex_reg_write,
        
        -- Pipeline registers input
        curr_PC_i           => id_curr_pc_to_ex,
        curr_inst_i         => id_curr_inst_to_ex,
        
        -- Outputs to MEM stage
        RegisterRes_o       => ex_write_reg_addr,
        alu_res_o           => ex_alu_result,
        DTCM_data_o         => ex_dtcm_write_data,
        pc_plus4_o          => ex_to_mem_pc_plus4,
        
        -- Control outputs to MEM stage
        MemtOReg_ctrl_o     => ex_to_mem_mem_to_reg,
        MemRead_ctrl_o      => ex_to_mem_mem_read,
        MemWrite_ctrl_o     => ex_to_mem_mem_write,
        RegWrite_ctrl_o     => ex_to_mem_reg_write,
        
        -- Pipeline registers output
        curr_pc_o           => EX_PC_o,
        curr_inst_o         => EX_inst_o,
        synch_curr_pc_o     => ex_curr_pc_to_mem,
        synch_curr_inst_o   => ex_curr_inst_to_mem
    );

-------------------------------------------------------------------------------------
-- MEMORY STAGE - WORD/BYTE GRANULARITY SELECTION
-------------------------------------------------------------------------------------
    G1: 
    if (WORD_GRANULARITY = True) generate -- Each WORD has unique address
        MEMORY_STAGE_WORD: dmemory
        GENERIC MAP(
            DATA_BUS_WIDTH      => DATA_BUS_WIDTH, 
            DTCM_ADDR_WIDTH     => DTCM_ADDR_WIDTH,
            WORDS_NUM           => DATA_WORDS_NUM,
            PC_WIDTH            => PC_WIDTH
        )
        PORT MAP (	
            clk_i               => master_clk,
            rst_i               => rst_i,
            
            -- Memory interface
            dtcm_data_wr_i      => ex_dtcm_write_data,
            dtcm_addr_i         => ex_alu_result((DTCM_ADDR_WIDTH)+1 DOWNTO 2),
            MemRead_ctrl_i      => ex_to_mem_mem_read,
            MemWrite_ctrl_i     => ex_to_mem_mem_write,
            
            -- Pipeline inputs
            pc_plus4_i          => ex_to_mem_pc_plus4,
            curr_PC_i           => ex_curr_pc_to_mem,
            curr_inst_i         => ex_curr_inst_to_mem,
            ALU_res_i           => ex_alu_result,
            RegisterRes_i       => ex_write_reg_addr,
            
            -- Control inputs
            MemtOReg_ctrl_i     => ex_to_mem_mem_to_reg,
            RegWrite_ctrl_i     => ex_to_mem_reg_write,
            
            -- Outputs to WB stage
            ALU_res_o           => mem_alu_result,
            RegisterRes_o       => mem_write_reg_addr,
            pc_plus4_o          => mem_to_wb_pc_plus4,
            dtcm_data_rd_o      => mem_dtcm_read_data,
            dtcm_data_rd_not_syncronic_o => mem_dtcm_read_data_async,
            
            -- Control outputs to WB stage
            MemtOReg_ctrl_o     => mem_to_wb_mem_to_reg,
            RegWrite_ctrl_o     => mem_to_wb_reg_write,
            
            -- Pipeline registers output
            curr_pc_o           => MEM_PC_o,
            curr_inst_o         => MEM_inst_o,
            synch_curr_pc_o     => mem_curr_pc_to_wb,
            synch_curr_inst_o   => mem_curr_inst_to_wb
        );		
    elsif (WORD_GRANULARITY = False) generate -- Each BYTE has a unique address	
        MEMORY_STAGE_BYTE: dmemory
        GENERIC MAP(
            DATA_BUS_WIDTH      => DATA_BUS_WIDTH, 
            DTCM_ADDR_WIDTH     => DTCM_ADDR_WIDTH,
            WORDS_NUM           => DATA_WORDS_NUM,
            PC_WIDTH            => PC_WIDTH
        )
        PORT MAP (	
            clk_i               => master_clk,
            rst_i               => rst_i,
            
            -- Memory interface (byte addressed)
            dtcm_addr_i         => ex_alu_result((DTCM_ADDR_WIDTH+2)-1 DOWNTO 2) & "00",
            dtcm_data_wr_i      => ex_dtcm_write_data,
            MemRead_ctrl_i      => ex_to_mem_mem_read,
            MemWrite_ctrl_i     => ex_to_mem_mem_write,
            
            -- Pipeline inputs
            pc_plus4_i          => ex_to_mem_pc_plus4,
            curr_PC_i           => ex_curr_pc_to_mem,
            curr_inst_i         => ex_curr_inst_to_mem,
            ALU_res_i           => ex_alu_result,
            RegisterRes_i       => ex_write_reg_addr,
            
            -- Control inputs
            MemtOReg_ctrl_i     => ex_to_mem_mem_to_reg,
            RegWrite_ctrl_i     => ex_to_mem_reg_write,
            
            -- Outputs to WB stage
            ALU_res_o           => mem_alu_result,
            RegisterRes_o       => mem_write_reg_addr,
            pc_plus4_o          => mem_to_wb_pc_plus4,
            dtcm_data_rd_o      => mem_dtcm_read_data,
            dtcm_data_rd_not_syncronic_o => mem_dtcm_read_data_async,
            
            -- Control outputs to WB stage
            MemtOReg_ctrl_o     => mem_to_wb_mem_to_reg,
            RegWrite_ctrl_o     => mem_to_wb_reg_write,
            
            -- Pipeline registers output
            curr_pc_o           => MEM_PC_o,
            curr_inst_o         => MEM_inst_o,
            synch_curr_pc_o     => mem_curr_pc_to_wb,
            synch_curr_inst_o   => mem_curr_inst_to_wb
        );
    end generate;

-------------------------------------------------------------------------------------
-- FORWARDING MUX FOR MEMORY TO EXECUTE BYPASS
-------------------------------------------------------------------------------------
    -- Non-synchronous forwarding from memory to execute stage
    forward_mem_to_ex_mux <= mem_alu_result WHEN (ex_to_mem_mem_to_reg = "00") ELSE
                             mem_dtcm_read_data_async;

-------------------------------------------------------------------------------------
-- HAZARD DETECTION UNIT
-------------------------------------------------------------------------------------
    HAZARD_UNIT: Hazard_detection_unit
    PORT MAP(
        -- Register addresses for hazard detection
        RegRtEx             => id_to_ex_reg_t,
        RegRtID             => if_instruction(20 DOWNTO 16),
        RegRdEx             => id_to_ex_reg_d,
        RegRsID             => if_instruction(25 DOWNTO 21),
        
        -- Control signals
        Reg_writeEx         => id_to_ex_reg_write,
        Branch_cond         => hazard_branch_condition,
        RegDstEx            => id_to_ex_reg_dst,
        -- Hazard control outputs
        stall_cnt           => hazard_stall_cnt,
        stall_pc            => hazard_stall_pc
    );

-------------------------------------------------------------------------------------
-- FORWARDING UNIT
-------------------------------------------------------------------------------------
    FORWARDING_UNIT: ForwordingUnit
    PORT MAP(
        -- Clock
        clk                 => master_clk,
        
        -- Register addresses for forwarding detection
        RegisterRdMEM       => ex_write_reg_addr,
        RegisterRdWB        => mem_write_reg_addr,
        RegisterRsEX        => id_to_ex_reg_s,
        RegisterRtEX        => id_to_ex_reg_t,
        RegisterRsDEC       => if_instruction(25 DOWNTO 21),
        RegisterRtDEC       => if_instruction(20 DOWNTO 16),
        
        -- Write enable signals
        RegisteWriteMem     => ex_to_mem_reg_write,
        RegisteWriteWB      => mem_to_wb_reg_write,
        
        -- Forwarding control outputs
        ForwardRS_Exe       => forward_rs_to_ex,
        ForwardRT_Exe       => forward_rt_to_ex,
        ForwardRT_Dec       => forward_rt_to_id,
        ForwardRS_Dec       => forward_rs_to_id
    );

-------------------------------------------------------------------------------------
-- WRITE BACK STAGE DATA MUX
-------------------------------------------------------------------------------------
    -- Multiplexer to select write back data
    wb_write_reg_data <= mem_alu_result WHEN (mem_to_wb_mem_to_reg = "00") ELSE
                         (X"00000" & B"00" & mem_to_wb_pc_plus4) WHEN (mem_to_wb_mem_to_reg = "01") ELSE
                         mem_dtcm_read_data;
                         
    -- JAL instruction register address mux (writes to register 31)
    wb_write_reg_addr_mux <= "11111" WHEN (mem_to_wb_mem_to_reg = "01") ELSE 
                             mem_write_reg_addr;

    -- Feedback signals for forwarding
    wb_alu_result_feedback <= mem_alu_result;
    wb_dtcm_data_feedback <= mem_dtcm_read_data;

-------------------------------------------------------------------------------------
-- BREAKPOINT AND CONTROL LOGIC
-------------------------------------------------------------------------------------
    -- Breakpoint detection
    breakpoint_pc <= IF_PC_o;
    program_run_enable <= '1' WHEN (PBADD_i = breakpoint_pc) ELSE '0'; 
                                     
    
    -- Combined stall control
    stall_or_run_control <= '1' WHEN (hazard_stall_cnt) ELSE '0';

    -- Pipeline flush control - detect jumps/branches for counting (natural timing handles actual flush)
    flush_pipeline <= '1' WHEN (id_pc_select = "01" OR id_pc_select = "10") ELSE '0';  -- For statistics only

-------------------------------------------------------------------------------------
-- PERFORMANCE COUNTERS AND STATISTICS
-------------------------------------------------------------------------------------
    -- Stall and flush counters
    PERFORMANCE_COUNTERS: process (master_clk, rst_i)
    begin
        if rst_i = '1' then
            perf_stall_count <= (others => '0');
            perf_flush_count <= (others => '0');
            flush_pipeline_prev <= '0';
        elsif rising_edge(master_clk) then
            -- Increment stall counter when stalling
            if hazard_stall_cnt = '1' then
                perf_stall_count <= perf_stall_count + '1';
            end if;
            
            -- Increment flush counter when flushing pipeline
            if flush_pipeline = '1' AND flush_pipeline_prev = '0' then
                perf_flush_count <= perf_flush_count + '1';
            end if;
            
            flush_pipeline_prev <= flush_pipeline;
        end if;
    end process;
    
    -- Master clock counter for IPC calculation
    MASTER_CLOCK_COUNTER: process (master_clk, rst_i)
    begin
        if rst_i = '1' then
            master_clk_cnt <= (others => '0');
        elsif rising_edge(master_clk) then
            master_clk_cnt <= master_clk_cnt + '1';
        end if;
    end process;
    
    -- Instruction counter (from IF stage)
    perf_inst_count <= if_instruction_count;

-------------------------------------------------------------------------------------
-- OUTPUT ASSIGNMENTS FOR PERFORMANCE MONITORING
-------------------------------------------------------------------------------------
    -- Performance counter outputs
    STRIGGER_o <= program_run_enable;
    FH_cnt_o <= perf_flush_count;
    ST_cnt_o <= perf_stall_count;

-------------------------------------------------------------------------------------
-- LEGACY SIGNAL ASSIGNMENTS (for backward compatibility)
-------------------------------------------------------------------------------------
    -- These signals maintain compatibility with existing testbenches
    instruction_w <= if_instruction;
    read_data1_w <= id_read_data1;
    read_data2_w <= id_read_data2;
    alu_result_w <= ex_alu_result;
    dtcm_data_rd_w <= mem_dtcm_read_data;
    branch_w <= ctrl_branch;
    zero_w <= ex_zero_flag;
    reg_write_w <= mem_to_wb_reg_write;
    mem_write_w <= ex_to_mem_mem_write;
    MemtoReg_w <= mem_to_wb_mem_to_reg;
    
    -- Additional debug outputs
    pc_o <= if_pc_debug;

-------------------------------------------------------------------------------------
END structure;