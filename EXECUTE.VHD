---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
-- Execute module (implements the data ALU and Branch Address Adder for the MIPS computer)
-- This module handles arithmetic/logic operations, data forwarding, and pipeline control
---------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.all;
USE work.const_package.all;

---------------------------------------------------------------------------------------------
-- ENTITY DECLARATION
---------------------------------------------------------------------------------------------
ENTITY Execute IS
    GENERIC(
        DATA_BUS_WIDTH : integer := 32;
        FUNCT_WIDTH    : integer := 6;
        PC_WIDTH       : integer := 10
    );
    PORT(
        -- Clock
        clk_i : IN STD_LOGIC;
        
        -- Data inputs from register file
        read_data1_i  : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- RS register data
        read_data2_i  : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- RT register data
        sign_extend_i : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Sign-extended immediate
        
        -- Instruction decode inputs
        funct_i : IN STD_LOGIC_VECTOR(6-1 DOWNTO 0);  -- Function field for R-type instructions
        
        -- Control signals from control unit
        ALUOp_ctrl_i  : IN STD_LOGIC_VECTOR(5 DOWNTO 0);  -- ALU operation control
        ALUSrc_ctrl_i : IN STD_LOGIC;                      -- ALU source select (reg vs immediate)
        RegDst_ctrl_i : IN STD_LOGIC;                      -- Register destination select
        
        -- Memory stage control signals (pass-through)
        MemRead_ctrl_i  : IN STD_LOGIC;
        MemWrite_ctrl_i : IN STD_LOGIC;
        MemRead_ctrl_o  : OUT STD_LOGIC;
        MemWrite_ctrl_o : OUT STD_LOGIC;
        
        -- Write-back stage control signals (pass-through)
        MemtOReg_ctrl_i : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        RegWrite_ctrl_i : IN STD_LOGIC;
        MemtOReg_ctrl_o : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        RegWrite_ctrl_o : OUT STD_LOGIC;
        
        -- Program counter and instruction tracking
        curr_PC_i         : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        curr_inst_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        pc_plus4_i        : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        curr_pc_o         : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        curr_inst_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        synch_curr_pc_o   : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        synch_curr_inst_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        pc_plus4_o        : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        
        -- Data forwarding inputs
        ForwardRS     : IN STD_LOGIC_VECTOR(1 DOWNTO 0);                    -- Forward control for RS
        ForwardRT     : IN STD_LOGIC_VECTOR(1 DOWNTO 0);                    -- Forward control for RT
        RegForwardMEM : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);     -- Forward data from MEM stage
        RegForwarWB   : IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);     -- Forward data from WB stage
        
        -- Register address inputs/outputs
        RegisterS_i   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Source register address
        RegisterT_i   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Target register address
        RegisterD_i   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Destination register address
        RegisterRes_o : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Selected destination register
        
        -- Data outputs
        alu_res_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- ALU result
        DTCM_data_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)   -- Data for memory write
    );
END Execute;

---------------------------------------------------------------------------------------------
-- ARCHITECTURE IMPLEMENTATION
---------------------------------------------------------------------------------------------
ARCHITECTURE behavior OF Execute IS

    -- Component declaration for barrel shifter
    COMPONENT Shifter
        GENERIC(
            n : integer := 32;  -- Data width
            k : integer := 5;   -- Shift amount width
            m : integer := 4    -- Control width
        );
        PORT(
            x     : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);    -- Shift amount (extended to n bits)
            y     : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);    -- Data to be shifted
            ALUFN : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);      -- Shift operation control
            res   : OUT STD_LOGIC_VECTOR(n-1 DOWNTO 0);    -- Shifted result
            cout  : OUT STD_LOGIC                          -- Carry out (unused)
        );
    END COMPONENT;

    -----------------------------------------------------------------------------------------
    -- INTERNAL SIGNALS
    -----------------------------------------------------------------------------------------
    
    -- ALU input signals after forwarding multiplexers
    SIGNAL alu_input_a        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- ALU A input (from RS)
    SIGNAL alu_input_b        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- ALU B input (reg or immediate)
    SIGNAL forwarded_rt_data  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- RT data after forwarding
    
    -- ALU control and operation signals
    SIGNAL alu_control_bits   : STD_LOGIC_VECTOR(3 DOWNTO 0);                 -- Internal ALU operation control
    SIGNAL alu_raw_result     : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Raw ALU output before post-processing
    SIGNAL alu_final_result   : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Final ALU result after SLT processing
    
    -- Shift operation signals
    SIGNAL shift_amount       : STD_LOGIC_VECTOR(4 DOWNTO 0);                 -- 5-bit shift amount
    SIGNAL shift_control      : STD_LOGIC_VECTOR(2 DOWNTO 0);                 -- Shifter operation control
    SIGNAL shift_result       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- Shifter output
    SIGNAL shift_carry_out    : STD_LOGIC;                                     -- Shifter carry (unused)
    
    -- Register destination selection
    SIGNAL selected_dest_reg  : STD_LOGIC_VECTOR(4 DOWNTO 0);                 -- Selected destination register
    
    -- Branch address calculation (currently unused)
    SIGNAL branch_address     : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    -----------------------------------------------------------------------------------------
    -- DATA FORWARDING LOGIC
    -----------------------------------------------------------------------------------------
    
    -- Forward RS register data based on hazard detection
    forwarding_mux_rs: PROCESS(ForwardRS, read_data1_i, RegForwardMEM, RegForwarWB)
    BEGIN
        CASE ForwardRS IS
            WHEN "00"   => alu_input_a <= read_data1_i;   -- No forwarding, use register file data
            WHEN "01"   => alu_input_a <= RegForwardMEM;  -- Forward from MEM stage
            WHEN "10"   => alu_input_a <= RegForwarWB;    -- Forward from WB stage
            WHEN OTHERS => alu_input_a <= X"00000000";    -- Default/error case
        END CASE;
    END PROCESS;
    
    -- Forward RT register data based on hazard detection
    forwarding_mux_rt: PROCESS(ForwardRT, read_data2_i, RegForwardMEM, RegForwarWB)
    BEGIN
        CASE ForwardRT IS
            WHEN "00"   => forwarded_rt_data <= read_data2_i;   -- No forwarding, use register file data
            WHEN "01"   => forwarded_rt_data <= RegForwardMEM;  -- Forward from MEM stage
            WHEN "10"   => forwarded_rt_data <= RegForwarWB;    -- Forward from WB stage
            WHEN OTHERS => forwarded_rt_data <= X"00000000";    -- Default/error case
        END CASE;
    END PROCESS;
    
    -- Select between forwarded register data and sign-extended immediate
    alu_src_mux: PROCESS(ALUSrc_ctrl_i, forwarded_rt_data, sign_extend_i)
    BEGIN
        IF ALUSrc_ctrl_i = '0' THEN
            alu_input_b <= forwarded_rt_data;  -- Use register data
        ELSE
            alu_input_b <= sign_extend_i;      -- Use immediate value
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------------------
    -- ALU CONTROL GENERATION
    -----------------------------------------------------------------------------------------
    
    -- Extract shift amount from immediate field (used for shift operations)
    shift_amount <= sign_extend_i(10 DOWNTO 6);
    
    -- Generate ALU control signals based on instruction type and function code
    alu_control_gen: PROCESS(ALUOp_ctrl_i, funct_i)
    BEGIN
        CASE ALUOp_ctrl_i IS
            -- R-type instructions (use function field)
            WHEN "000010" =>
                CASE funct_i IS
                    WHEN AND_FUNCT       => alu_control_bits <= "0000";  -- AND operation
                    WHEN SHIFT_L_FUNCT   => alu_control_bits <= "0011";  -- Shift left logical
                    WHEN SHIFT_R_FUNCT   => alu_control_bits <= "0101";  -- Shift right logical
                    WHEN SUB_FUNCT       => alu_control_bits <= "0110";  -- Subtract
                    WHEN ADD_FUNCT       => alu_control_bits <= "0010";  -- Add
                    WHEN OR_FUNCT        => alu_control_bits <= "0001";  -- OR operation
                    WHEN XOR_FUNCT       => alu_control_bits <= "0100";  -- XOR operation
                    WHEN SLT_FUNCT       => alu_control_bits <= "0111";  -- Set less than
                    WHEN ADDU_FUNCT      => alu_control_bits <= "1010";  -- Add unsigned
                    WHEN JUMP_REG_fUNCT  => alu_control_bits <= "1100";  -- Jump register
                    WHEN OTHERS          => alu_control_bits <= "1111";  -- Invalid/unsupported
                END CASE;
                
            -- Branch instructions
            WHEN "000001" => alu_control_bits <= "0110";  -- Subtract for comparison
            
            -- Immediate OR instruction
            WHEN "000000" => alu_control_bits <= "0001";  -- OR operation
            
            -- Immediate XOR instruction
            WHEN "000100" => alu_control_bits <= "0100";  -- XOR operation
            
            -- Immediate AND instruction
            WHEN "001000" => alu_control_bits <= "0000";  -- AND operation
            
            -- Add immediate, load word, store word
            WHEN "001100" => alu_control_bits <= "0010";  -- Add operation
            
            -- Multiplication instruction
            WHEN "010000" => alu_control_bits <= "1000";  -- Multiply operation
            
            -- Set less than immediate
            WHEN "100000" => alu_control_bits <= "0111";  -- Set less than
            
            -- Add immediate unsigned
            WHEN "011000" => alu_control_bits <= "1010";  -- Add unsigned
            
            -- Load/Store instructions (pass immediate through)
            WHEN "100100" => alu_control_bits <= "1011";  -- Pass B input through
            
            -- Default case for unsupported operations
            WHEN OTHERS => alu_control_bits <= "1111";
        END CASE;
    END PROCESS;

    -----------------------------------------------------------------------------------------
    -- BARREL SHIFTER CONFIGURATION
    -----------------------------------------------------------------------------------------
    
    -- Generate shifter control signals
    shift_control_gen: PROCESS(alu_control_bits)
    BEGIN
        CASE alu_control_bits IS
            WHEN "0011" => shift_control <= "000";  -- Shift left logical
            WHEN "0101" => shift_control <= "001";  -- Shift right logical
            WHEN OTHERS => shift_control <= "000";  -- Default to left shift
        END CASE;
    END PROCESS;
    
    -- Instantiate barrel shifter module
    barrel_shifter: Shifter
        GENERIC MAP(
            n => DATA_BUS_WIDTH,
            k => 5,  -- 5-bit shift amount for 32-bit data
            m => 4   -- Original parameter
        )
        PORT MAP(
            x     => X"000000" & "000" & shift_amount,  -- Zero-extend shift amount to 32 bits
            y     => alu_input_b,                       -- Data to be shifted
            ALUFN => shift_control,                     -- Shift operation type
            res   => shift_result,                      -- Shifted result
            cout  => shift_carry_out                    -- Carry output (unused)
        );

    -----------------------------------------------------------------------------------------
    -- ALU OPERATION EXECUTION
    -----------------------------------------------------------------------------------------
    
    -- Main ALU operations multiplexer
    alu_operations: PROCESS(alu_control_bits, alu_input_a, alu_input_b, shift_result)
    BEGIN
        CASE alu_control_bits IS
            -- Bitwise AND
            WHEN "0000" => alu_raw_result <= alu_input_a AND alu_input_b;
            
            -- Bitwise OR
            WHEN "0001" => alu_raw_result <= alu_input_a OR alu_input_b;
            
            -- Signed addition
            WHEN "0010" => alu_raw_result <= STD_LOGIC_VECTOR(signed(alu_input_a) + signed(alu_input_b));
            
            -- Shift left logical (use shifter result)
            WHEN "0011" => alu_raw_result <= shift_result;
            
            -- Bitwise XOR
            WHEN "0100" => alu_raw_result <= alu_input_a XOR alu_input_b;
            
            -- Shift right logical (use shifter result)
            WHEN "0101" => alu_raw_result <= shift_result;
            
            -- Signed subtraction
            WHEN "0110" => alu_raw_result <= STD_LOGIC_VECTOR(signed(alu_input_a) - signed(alu_input_b));
            
            -- Set less than (signed comparison)
            WHEN "0111" => alu_raw_result <= STD_LOGIC_VECTOR(signed(alu_input_a) - signed(alu_input_b));
            
            -- Multiplication (16-bit x 16-bit = 32-bit result)
            WHEN "1000" => alu_raw_result <= STD_LOGIC_VECTOR(
                unsigned(alu_input_a(DATA_BUS_WIDTH/2-1 DOWNTO 0)) * 
                unsigned(alu_input_b(DATA_BUS_WIDTH/2-1 DOWNTO 0))
            );
            
            -- Load upper immediate (place immediate in upper 16 bits)
            WHEN "1001" => alu_raw_result <= alu_input_b(DATA_BUS_WIDTH/2-1 DOWNTO 0) & X"0000";
            
            -- Unsigned addition
            WHEN "1010" => alu_raw_result <= STD_LOGIC_VECTOR(unsigned(alu_input_a) + unsigned(alu_input_b));
            
            -- Pass B input through (for load/store address calculation)
            WHEN "1011" => alu_raw_result <= alu_input_b;
            
            -- Jump register (pass A input through)
            WHEN "1100" => alu_raw_result <= alu_input_a;
            
            -- Default case (output zero)
            WHEN OTHERS => alu_raw_result <= X"00000000";
        END CASE;
    END PROCESS;
    
    -- Post-process ALU result for set-less-than operations
    slt_result_processing: PROCESS(alu_control_bits, alu_raw_result)
    BEGIN
        IF alu_control_bits = "0111" THEN  -- SLT operation
            -- Extract sign bit and zero-extend to create boolean result
            alu_final_result <= X"0000000" & B"000" & alu_raw_result(31);
        ELSE
            -- Pass through raw result for all other operations
            alu_final_result <= alu_raw_result;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------------------
    -- REGISTER DESTINATION SELECTION
    -----------------------------------------------------------------------------------------
    
    -- Select destination register based on instruction type
    dest_reg_mux: PROCESS(RegDst_ctrl_i, RegisterD_i, RegisterT_i)
    BEGIN
        IF RegDst_ctrl_i = '1' THEN
            selected_dest_reg <= RegisterD_i;  -- R-type: use RD field
        ELSE
            selected_dest_reg <= RegisterT_i;  -- I-type: use RT field
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------------------
    -- PIPELINE REGISTER PROCESS
    -----------------------------------------------------------------------------------------
    
    -- Pipeline register to pass signals to next stage
    pipeline_registers: PROCESS(clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- Pass-through control signals for Write-Back stage
            MemtOReg_ctrl_o <= MemtOReg_ctrl_i;
            RegWrite_ctrl_o <= RegWrite_ctrl_i;
            
            -- Pass-through control signals for Memory stage
            MemRead_ctrl_o  <= MemRead_ctrl_i;
            MemWrite_ctrl_o <= MemWrite_ctrl_i;
            
            -- Data outputs to next stage
            alu_res_o   <= alu_final_result;     -- ALU computation result
            DTCM_data_o <= forwarded_rt_data;    -- Data for memory write operations
            
            -- Register and instruction tracking
            RegisterRes_o     <= selected_dest_reg;
            pc_plus4_o        <= pc_plus4_i;
            synch_curr_pc_o   <= curr_PC_i;
            synch_curr_inst_o <= curr_inst_i;
        END IF;
    END PROCESS;

    -----------------------------------------------------------------------------------------
    -- COMBINATIONAL OUTPUTS
    -----------------------------------------------------------------------------------------
    
    -- Direct pass-through outputs (not registered)
    curr_pc_o   <= curr_PC_i;
    curr_inst_o <= curr_inst_i;
    
    -- Branch address calculation (currently unused in the design)
    -- branch_address <= STD_LOGIC_VECTOR(unsigned(pc_plus4_i(PC_WIDTH-1 DOWNTO 2)) + 
    --                                    unsigned(sign_extend_i(7 DOWNTO 0)));

END behavior;