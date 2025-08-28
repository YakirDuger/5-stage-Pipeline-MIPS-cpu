---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- Data Memory module (implements the data memory for the MIPS computer)
-- This module provides data memory access for load/store instructions and handles
-- pipeline control signal pass-through to the write-back stage
---------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

---------------------------------------------------------------------------------------------
-- ENTITY DECLARATION
---------------------------------------------------------------------------------------------
ENTITY dmemory IS
    GENERIC(
        DATA_BUS_WIDTH  : integer := 32;   -- Width of data bus
        DTCM_ADDR_WIDTH : integer := 8;    -- Width of memory address bus
        WORDS_NUM       : integer := 256;  -- Number of memory words
        PC_WIDTH        : integer := 10    -- Width of program counter
    );
    PORT(
        -- Clock and reset
        clk_i : IN STD_LOGIC;
        rst_i : IN STD_LOGIC;
        
        -- Data memory interface
        dtcm_addr_i    : IN  STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);  -- Memory address
        dtcm_data_wr_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);   -- Data to write
        dtcm_data_rd_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);   -- Data read (registered)
        dtcm_data_rd_not_syncronic_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- Data read (combinational)
        
        -- Memory control signals
        MemRead_ctrl_i  : IN STD_LOGIC;  -- Memory read enable
        MemWrite_ctrl_i : IN STD_LOGIC;  -- Memory write enable
        
        -- Write-back stage control signals (pass-through)
        MemtOReg_ctrl_i : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);  -- Memory-to-register select
        RegWrite_ctrl_i : IN  STD_LOGIC;                      -- Register write enable
        MemtOReg_ctrl_o : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);  -- Memory-to-register select (output)
        RegWrite_ctrl_o : OUT STD_LOGIC;                      -- Register write enable (output)
        
        -- ALU result pass-through
        ALU_res_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- ALU result input
        ALU_res_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- ALU result output
        
        -- Register destination pass-through
        RegisterRes_i : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Destination register input
        RegisterRes_o : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Destination register output
        
        -- Program counter tracking
        pc_plus4_i        : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);  -- PC+4 input
        pc_plus4_o        : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);  -- PC+4 output
        curr_PC_i         : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);  -- Current PC input
        curr_inst_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Current instruction input
        curr_pc_o         : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);  -- Current PC output (combinational)
        curr_inst_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Current instruction output (combinational)
        synch_curr_pc_o   : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);  -- Current PC output (registered)
        synch_curr_inst_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)   -- Current instruction output (registered)
    );
END dmemory;

---------------------------------------------------------------------------------------------
-- ARCHITECTURE IMPLEMENTATION
---------------------------------------------------------------------------------------------
ARCHITECTURE behavior OF dmemory IS

    -----------------------------------------------------------------------------------------
    -- INTERNAL SIGNALS
    -----------------------------------------------------------------------------------------
    
    -- Memory interface signals
    SIGNAL memory_write_clock : STD_LOGIC;                                     -- Inverted clock for memory writes
    SIGNAL memory_read_data   : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Raw memory read data

BEGIN

    -----------------------------------------------------------------------------------------
    -- DATA MEMORY INSTANTIATION
    -----------------------------------------------------------------------------------------
    
    -- Altera synchronous RAM block for data memory
    -- Uses single-port configuration with separate read/write operations
    data_memory_block: altsyncram
        GENERIC MAP (
            operation_mode         => "SINGLE_PORT",                    -- Single port operation
            width_a               => DATA_BUS_WIDTH,                    -- Data width (32 bits)
            widthad_a             => DTCM_ADDR_WIDTH,                   -- Address width (8 bits)
            numwords_a            => WORDS_NUM,                         -- Number of words (256)
            lpm_hint              => "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = DTCM",
            lpm_type              => "altsyncram",                      -- Altera sync RAM type
            outdata_reg_a         => "UNREGISTERED",                    -- Unregistered output for faster access
            init_file             => "D:\LAB5\SW\SW\EX1\bin\DTCM.hex", -- Memory initialization file
            intended_device_family => "Cyclone"                        -- Target FPGA family
        )
        PORT MAP (
            wren_a    => MemWrite_ctrl_i,    -- Write enable from control unit
            clock0    => memory_write_clock, -- Memory clock (inverted system clock)
            address_a => dtcm_addr_i,        -- Memory address from ALU
            data_a    => dtcm_data_wr_i,     -- Write data from register file
            q_a       => memory_read_data    -- Read data output
        );

    -----------------------------------------------------------------------------------------
    -- MEMORY CLOCK GENERATION
    -----------------------------------------------------------------------------------------
    
    -- Generate inverted clock for memory operations
    -- This ensures proper timing for memory read/write operations in the pipeline
    memory_write_clock <= NOT clk_i;

    -----------------------------------------------------------------------------------------
    -- PIPELINE REGISTER PROCESS
    -----------------------------------------------------------------------------------------
    
    -- Pipeline registers to pass control signals and data to write-back stage
    pipeline_registers: PROCESS(clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- Pass-through write-back control signals
            RegWrite_ctrl_o <= RegWrite_ctrl_i;    -- Register write enable
            MemtOReg_ctrl_o <= MemtOReg_ctrl_i;    -- Memory-to-register multiplexer control
            
            -- Pass-through register destination
            RegisterRes_o <= RegisterRes_i;        -- Destination register address
            
            -- Pass-through ALU result
            ALU_res_o <= ALU_res_i;                -- ALU computation result
            
            -- Register memory read data for write-back stage
            dtcm_data_rd_o <= memory_read_data;    -- Memory read data (for load instructions)
            
            -- Pass-through program counter
            pc_plus4_o <= pc_plus4_i;              -- PC+4 for return address
            
            -- Register instruction tracking signals for debugging/monitoring
            synch_curr_pc_o   <= curr_PC_i;        -- Current program counter
            synch_curr_inst_o <= curr_inst_i;      -- Current instruction
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------------------
    -- COMBINATIONAL OUTPUTS
    -----------------------------------------------------------------------------------------
    
    -- Direct pass-through outputs (not registered)
    -- These provide immediate access to current instruction information
    curr_pc_o   <= curr_PC_i;      -- Current program counter (combinational)
    curr_inst_o <= curr_inst_i;    -- Current instruction (combinational)
    
    -- Provide immediate (non-registered) access to memory read data
    -- This allows for faster memory access when timing permits
    dtcm_data_rd_not_syncronic_o <= memory_read_data;

END behavior;