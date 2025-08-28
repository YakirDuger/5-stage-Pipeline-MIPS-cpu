---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- MIPS Constants Package
-- Contains all instruction opcodes and function codes for MIPS processor
---------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE const_package IS

    ----------------------------------------------------------------------------
    -- INSTRUCTION OPCODES (6-bit)
    ----------------------------------------------------------------------------
    
    -- R-Type Instructions
    CONSTANT R_TYPE_OPC         : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000000";  -- R-type format
    
    -- Memory Access Instructions
    CONSTANT LW_OPC             : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100011";  -- Load word
    CONSTANT SW_OPC             : STD_LOGIC_VECTOR(5 DOWNTO 0) := "101011";  -- Store word
    
    -- Branch Instructions
    CONSTANT BEQ_OPC            : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000100";  -- Branch if equal
    CONSTANT BNE_OPC            : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000101";  -- Branch if not equal
    
    -- Immediate Arithmetic Instructions
    CONSTANT ADDI_OPC           : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001000";  -- Add immediate
    CONSTANT ADDI_UNSIGNED_OPC  : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001001";  -- Add immediate unsigned
    CONSTANT SLTI_OPC           : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001010";  -- Set less than immediate
    
    -- Immediate Logical Instructions
    CONSTANT ANDI_OPC           : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001100";  -- AND immediate
    CONSTANT ORI_OPC            : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001101";  -- OR immediate
    CONSTANT XORI_OPC           : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001110";  -- XOR immediate
    CONSTANT LUI_OPC            : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001111";  -- Load upper immediate
    
    -- Jump Instructions
    CONSTANT JUMP_OPC           : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000010";  -- Jump
    CONSTANT JUMP_LINK_OPC      : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000011";  -- Jump and link
    
    -- Special Instructions
    CONSTANT MUL_OPC            : STD_LOGIC_VECTOR(5 DOWNTO 0) := "011100";  -- Multiply
    
    ----------------------------------------------------------------------------
    -- FUNCTION CODES (6-bit) - Used with R-Type Instructions
    ----------------------------------------------------------------------------
    
    -- Arithmetic Functions
    CONSTANT ADD_FUNCT          : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100000";  -- Add
    CONSTANT ADDU_FUNCT         : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100001";  -- Add unsigned
    CONSTANT SUB_FUNCT          : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100010";  -- Subtract
    CONSTANT SLT_FUNCT          : STD_LOGIC_VECTOR(5 DOWNTO 0) := "101010";  -- Set less than
    CONSTANT MUL_FUNCT          : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000010";  -- Multiply (same as SHIFT_R_FUNCT)
    
    -- Logical Functions
    CONSTANT AND_FUNCT          : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100100";  -- Bitwise AND
    CONSTANT OR_FUNCT           : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100101";  -- Bitwise OR
    CONSTANT XOR_FUNCT          : STD_LOGIC_VECTOR(5 DOWNTO 0) := "100110";  -- Bitwise XOR
    
    -- Shift Functions
    CONSTANT SHIFT_L_FUNCT      : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000000";  -- Shift left logical
    CONSTANT SHIFT_R_FUNCT      : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000010";  -- Shift right logical
    
    -- Jump Functions
    CONSTANT JUMP_REG_FUNCT     : STD_LOGIC_VECTOR(5 DOWNTO 0) := "001000";  -- Jump register
    
    ----------------------------------------------------------------------------
    -- NOTES:
    -- - MUL_FUNCT has the same encoding as SHIFT_R_FUNCT ("000010")
    --   They are distinguished by different ALU operation codes
    -- - All constants follow MIPS ISA standard encoding
    ----------------------------------------------------------------------------

END const_package;