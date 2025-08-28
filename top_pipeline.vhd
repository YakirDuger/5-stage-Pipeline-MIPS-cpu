LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.aux_package.all;

entity top_pipeline is
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
        STCNT_o            : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0)        -- TOOK IT OUT ONLY FOR THE QUARTUS ! (IT DOESN'T COMPILE WELL BECAUSE OF THE AMOUNT OF OUTPUT PINS)
        
        --mclk_cnt_o         : OUT STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
        --inst_cnt_o         : OUT STD_LOGIC_VECTOR(INST_CNT_WIDTH-1 DOWNTO 0)
    );
end top_pipeline;

architecture Behavioral of top_pipeline is
begin
    -- Instantiate the MIPS module
    mips_core_inst : MIPS
        port map (
            clk_i               => clk_i,
            rst_i               => rst_i,
            PBADD_i            => BPADDR_i,
            
            -- Map only the signals needed for Figure 8
            --mclk_cnt_o          => CLKCNT_o,
            --inst_cnt_o          => INSTCNT_o,

            -- Pipeline stage PC tracking
            IF_PC_o              => IFpc_o,
            ID_PC_o              => IDpc_o,
            EX_PC_o              => EXpc_o,
            MEM_PC_o             => MEMpc_o,
            WB_PC_o              => WBpc_o,
  
            -- Pipeline stage instruction tracking
            IF_inst_o     => IFinstruction_o,
            ID_inst_o     => IDinstruction_o,
            EX_inst_o     => EXinstruction_o,
            MEM_inst_o    => MEMinstruction_o,
            WB_inst_o     => WBinstruction_o,
            
            -- Performance counters
            STRIGGER_o          => STRIGGER_o,
            FH_cnt_o             => FHCNT_o,
            ST_cnt_o             => STCNT_o,  -- TOOK IT OUT ONLY FOR THE QUARTUS ! (IT DOESN'T COMPILE WELL BECAUSE OF THE AMOUNT OF OUTPUT PINS)
            
            --mclk_cnt_o      => mclk_cnt_o,
            --inst_cnt_o      => inst_cnt_o,


            -- Unused outputs (connected to open)
            pc_o                => open,
            alu_result_o        => open,
            read_data1_o        => open,
            read_data2_o        => open,
            write_data_o        => open,
            instruction_top_o   => open,
            Branch_ctrl_o       => open,
            Zero_o              => open,
            MemWrite_ctrl_o     => open,
            RegWrite_ctrl_o     => open
        );
end Behavioral; 