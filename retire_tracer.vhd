-------------------------------------------------------------------------------
-- retire_tracer.vhd
--
-- Simulation-only observer.  Dumps the CPU's architectural effect streams to
-- two text files so they can be diffed against a golden ISS.
--
--   <reg file>  "<pc_word> R <reg> <value>"
--   <mem file>  "<pc_word> M <word_addr|PERIPH> <value>"
--
-- Contains no drivers on any design signal.  Set ENABLE => false (or simply
-- do not instantiate it) for synthesis.
--
-- Both processes sample on the FALLING edge, because that is when this design
-- actually commits: the register file in Idecode.vhd writes on clock='0', and
-- dmemory's altsyncram is clocked by (not clk_i).
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use STD.TEXTIO.all;

entity retire_tracer is
    generic (
        ENABLE   : boolean := true;
        REG_FILE : string  := "rtl.reg.trace";
        MEM_FILE : string  := "rtl.mem.trace"
    );
    port (
        clock, reset    : in std_logic;
        -- ---- WB stage (register commit) ----
        RegWrite_WB     : in std_logic;
        Wr_reg_addr_WB  : in std_logic_vector(4 downto 0);
        write_data_WB   : in std_logic_vector(31 downto 0); -- map write_data_mux_WB
        PC_plus_4_WB    : in std_logic_vector(9 downto 0);
        -- ---- MEM stage (memory commit) ----
        MemWrite_MEM    : in std_logic;
        is_periph_MEM   : in std_logic;
        ALU_Result_MEM  : in std_logic_vector(31 downto 0);
        write_data_MEM  : in std_logic_vector(31 downto 0);
        PC_plus_4_MEM   : in std_logic_vector(9 downto 0)
    );
end retire_tracer;

architecture sim of retire_tracer is

    -- Hex formatter that survives 'X' / 'U' instead of crashing the run.
    function to_hex(v : std_logic_vector) return string is
        constant NIB : integer := (v'length + 3) / 4;
        variable pad : std_logic_vector(NIB*4-1 downto 0) := (others => '0');
        variable s   : string(1 to NIB);
        variable n   : integer;
        variable bad : boolean;
        constant TBL : string(1 to 16) := "0123456789abcdef";
    begin
        pad(v'length-1 downto 0) := v;
        for i in 0 to NIB-1 loop
            n := 0; bad := false;
            for b in 0 to 3 loop
                case pad(i*4 + b) is
                    when '1' | 'H' => n := n + 2**b;
                    when '0' | 'L' => null;
                    when others    => bad := true;
                end case;
            end loop;
            if bad then
                s(NIB - i) := 'x';
            else
                s(NIB - i) := TBL(n + 1);
            end if;
        end loop;
        return s;
    end function;

    -- PC of the instruction currently in a stage = (PC+4)>>2 - 1, 8-bit wrap.
    function pc_word(p4 : std_logic_vector(9 downto 0)) return std_logic_vector is
        variable u : unsigned(7 downto 0);
        variable bad : boolean := false;
    begin
        for i in 2 to 9 loop
            if p4(i) /= '0' and p4(i) /= '1' then bad := true; end if;
        end loop;
        if bad then
            return "XXXXXXXX";
        end if;
        u := unsigned(p4(9 downto 2)) - 1;
        return std_logic_vector(u);
    end function;

begin

    -----------------------------------------------------------------------
    -- Register commit stream
    -----------------------------------------------------------------------
    reg_trace : process(clock)
        file     f : text open write_mode is REG_FILE;
        variable l : line;
        variable started : boolean := false;
    begin
        if ENABLE and falling_edge(clock) then
            if reset = '0' then
                if RegWrite_WB = '1' and Wr_reg_addr_WB /= "00000" then
                    write(l, to_hex(pc_word(PC_plus_4_WB)));
                    write(l, string'(" R "));
                    write(l, to_integer(unsigned(Wr_reg_addr_WB)), right, 2);
                    write(l, string'(" "));
                    write(l, to_hex(write_data_WB));
                    writeline(f, l);
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------
    -- Memory commit stream
    -----------------------------------------------------------------------
    mem_trace : process(clock)
        file     f : text open write_mode is MEM_FILE;
        variable l : line;
    begin
        if ENABLE and falling_edge(clock) then
            if reset = '0' and MemWrite_MEM = '1' then
                write(l, to_hex(pc_word(PC_plus_4_MEM)));
                write(l, string'(" M "));
                if is_periph_MEM = '1' then
                    write(l, string'("PERIPH"));
                else
                    write(l, to_hex(ALU_Result_MEM(9 downto 2)));
                end if;
                write(l, string'(" "));
                write(l, to_hex(write_data_MEM));
                writeline(f, l);
            end if;
        end if;
    end process;

end sim;