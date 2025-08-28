---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- MIPS Control Unit Module
-- Implements control signal generation for MIPS processor
---------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.const_package.all;

ENTITY control IS
   PORT( 	
        -- Clock input
        clk_i               : IN    STD_LOGIC;
        
        -- Instruction decode inputs
        opcode_i            : IN    STD_LOGIC_VECTOR(5 DOWNTO 0);
        funct_i             : IN    STD_LOGIC_VECTOR(5 DOWNTO 0);
        
        -- Control signal outputs
        RegDst_ctrl_o       : OUT   STD_LOGIC;                      -- Register destination select
        ALUSrc_ctrl_o       : OUT   STD_LOGIC;                      -- ALU source select
        MemtoReg_ctrl_o     : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);  -- Memory to register select
        RegWrite_ctrl_o     : OUT   STD_LOGIC;                      -- Register write enable
        MemRead_ctrl_o      : OUT   STD_LOGIC;                      -- Memory read enable
        MemWrite_ctrl_o     : OUT   STD_LOGIC;                      -- Memory write enable
        Branch_ctrl_o       : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0);  -- Branch control
        ALUOp_ctrl_o        : OUT   STD_LOGIC_VECTOR(5 DOWNTO 0);  -- ALU operation control
        jump_o              : OUT   STD_LOGIC_VECTOR(1 DOWNTO 0)   -- Jump control
    );
END control;

ARCHITECTURE behavior OF control IS

    -- Instruction type detection signals
    SIGNAL is_rtype             : STD_LOGIC;
    SIGNAL is_load_word         : STD_LOGIC;
    SIGNAL is_store_word        : STD_LOGIC;
    SIGNAL is_itype_immediate   : STD_LOGIC;
    SIGNAL is_multiply          : STD_LOGIC;
    SIGNAL is_jump_and_link     : STD_LOGIC;
    SIGNAL branch_type          : STD_LOGIC_VECTOR(1 DOWNTO 0);

    -- Internal control signal temporaries
    SIGNAL regdst_internal      : STD_LOGIC;
    SIGNAL alusrc_internal      : STD_LOGIC;
    SIGNAL memtoreg_internal    : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL regwrite_internal    : STD_LOGIC;
    SIGNAL memread_internal     : STD_LOGIC;
    SIGNAL memwrite_internal    : STD_LOGIC;
    SIGNAL branch_internal      : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL aluop_internal       : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL jump_internal        : STD_LOGIC_VECTOR(1 DOWNTO 0);

BEGIN

    ----------------------------------------------------------------------------
    -- INSTRUCTION TYPE DETECTION
    ----------------------------------------------------------------------------
    
    -- R-type instruction detection
    is_rtype <= '1' WHEN (opcode_i = R_TYPE_OPC) ELSE '0';
    
    -- Memory access instruction detection
    is_load_word  <= '1' WHEN (opcode_i = LW_OPC) ELSE '0';
    is_store_word <= '1' WHEN (opcode_i = SW_OPC) ELSE '0';
    
    -- Multiply instruction detection
    is_multiply <= '1' WHEN (opcode_i = MUL_OPC) ELSE '0';
    
    -- Jump and link instruction detection
    is_jump_and_link <= '1' WHEN (opcode_i = JUMP_Link_OPC) ELSE '0';
    
    -- I-type immediate instructions detection
    is_itype_immediate <= '1' WHEN ((opcode_i = ADDI_OPC) OR 
                                    (opcode_i = ORI_OPC)  OR 
                                    (opcode_i = ANDI_OPC) OR
                                    (opcode_i = LUI_OPC) OR 
                                    (opcode_i = XORI_OPC) OR
                                    (opcode_i = SLTI_OPC) OR
                                    (opcode_i = ADDI_UNSIGNED_OPC))
                                ELSE '0';
    
    -- Branch type detection
    branch_type <= "00" WHEN (opcode_i = BEQ_OPC) ELSE    -- Branch if equal
                   "01" WHEN (opcode_i = BNE_OPC) ELSE    -- Branch if not equal
                   "11";                                   -- No branch

    ----------------------------------------------------------------------------
    -- JUMP CONTROL GENERATION
    ----------------------------------------------------------------------------
    
    jump_internal <= "01" WHEN ((opcode_i = JUMP_OPC) OR (opcode_i = JUMP_Link_OPC)) ELSE  -- Direct jump
                     "10" WHEN ((opcode_i = R_TYPE_OPC) AND (funct_i = JUMP_REG_FUNCT)) ELSE  -- Jump register
                     "00";  -- No jump

    ----------------------------------------------------------------------------
    -- CONTROL SIGNAL GENERATION
    ----------------------------------------------------------------------------
    
    -- Register destination control: selects rd for R-type and multiply instructions
    regdst_internal <= is_rtype OR is_multiply;
    
    -- ALU source control: selects immediate for memory ops and I-type immediate ops
    alusrc_internal <= is_load_word OR is_store_word OR is_itype_immediate;
    
    -- Memory to register control: selects data source for register write
    memtoreg_internal <= "10" WHEN (opcode_i = LW_OPC) ELSE        -- Load from memory
                         "01" WHEN (opcode_i = JUMP_Link_OPC) ELSE -- Jump and link (PC+4)
                         "00";                                      -- ALU result
    
    -- Register write enable: enables writing to register file
    regwrite_internal <= is_rtype OR is_load_word OR is_itype_immediate OR 
                         is_jump_and_link OR is_multiply;
    
    -- Memory read enable: enables reading from data memory
    memread_internal <= is_load_word;
    
    -- Memory write enable: enables writing to data memory
    memwrite_internal <= is_store_word;
    
    -- Branch control
    branch_internal <= branch_type;

    ----------------------------------------------------------------------------
    -- ALU OPERATION CONTROL GENERATION
    ----------------------------------------------------------------------------
    
    WITH opcode_i SELECT
        aluop_internal <= "000010" WHEN R_TYPE_OPC,           -- R-type operations
                          "000001" WHEN BNE_OPC,              -- Branch not equal
                          "000001" WHEN BEQ_OPC,              -- Branch equal
                          "000000" WHEN ORI_OPC,              -- OR immediate
                          "000100" WHEN XORI_OPC,             -- XOR immediate
                          "001000" WHEN ANDI_OPC,             -- AND immediate
                          "001100" WHEN ADDI_OPC,             -- ADD immediate
                          "010000" WHEN MUL_OPC,              -- Multiply
                          "010100" WHEN LUI_OPC,              -- Load upper immediate
                          "011000" WHEN ADDI_UNSIGNED_OPC,    -- ADD immediate unsigned
                          "100000" WHEN SLTI_OPC,             -- Set less than immediate
                          "001100" WHEN SW_OPC,               -- Store word
                          "001100" WHEN LW_OPC,               -- Load word
                          "011100" WHEN OTHERS;               -- Default (la, lu, li, jump)

    ----------------------------------------------------------------------------
    -- OUTPUT ASSIGNMENTS
    ----------------------------------------------------------------------------
    
    RegDst_ctrl_o   <= regdst_internal;
    ALUSrc_ctrl_o   <= alusrc_internal;
    MemtoReg_ctrl_o <= memtoreg_internal;
    RegWrite_ctrl_o <= regwrite_internal;
    MemRead_ctrl_o  <= memread_internal;
    MemWrite_ctrl_o <= memwrite_internal;
    Branch_ctrl_o   <= branch_internal;
    ALUOp_ctrl_o    <= aluop_internal;
    jump_o          <= jump_internal;

END behavior;