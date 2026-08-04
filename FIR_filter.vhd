library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;

entity FIR_FILTER is
  generic (
    DATA_WIDTH : integer := 24;   -- UQ24.0
    COEF_WIDTH : integer := 8;    -- UQ0.8
    M_TAPS     : integer := 8;
    Q_PARAM    : integer := 8;    -- fractional bits (coeff Q)
    FIFO_DEPTH : integer := 8
  );
  port (
    FIRCLK   : in  std_logic;
    FIFOCLK  : in  std_logic;

    -- Control Register Interface
    FIRCTL        : in  std_logic_vector(7 downto 0);  -- sw writes
    FIRCTL_STATUS : out std_logic_vector(7 downto 0);  -- sw reads

    -- Data
    FIRIN   : in  std_logic_vector(31 downto 0);  -- {0@8, x(23:0)}
    FIROUT  : out std_logic_vector(31 downto 0);  -- {0@8, y(23:0)}

    -- Interrupt (new output ready pulse in FIRCLK domain)
    FIRIFG  : out std_logic;

    -- Coefficients (UQ0.8)
    COEF0 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF1 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF2 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF3 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF4 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF5 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF6 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    COEF7 : in std_logic_vector(COEF_WIDTH-1 downto 0);
    CS_FIROUT : in std_logic;
        -- DEBUG OUTPUTS - Add these new signals
    -- FIFO Status
    DEBUG_FIFO_COUNT    : out std_logic_vector(4 downto 0);    -- FIFO count (0-16)
    DEBUG_FIFO_EMPTY   : out std_logic;                        -- FIFO empty flag
    DEBUG_FIFO_FULL    : out std_logic;                        -- FIFO full flag
    DEBUG_W_PTR        : out std_logic_vector(3 downto 0);     -- Write pointer
    DEBUG_R_PTR        : out std_logic_vector(3 downto 0);     -- Read pointer
    
    -- Handshake Status
    DEBUG_PENDING_REQ  : out std_logic;                        -- Pending request flag
    DEBUG_REQ_TOG_FIR : out std_logic;                         -- Request toggle from FIR
    DEBUG_ACK_TOG_FIFO: out std_logic;                         -- Ack toggle to FIR
    DEBUG_OUTSTANDING  : out std_logic;                         -- Outstanding request flag
    
    -- FIR Processing Status
    DEBUG_SAMPLE_VALID : out std_logic;                         -- Sample valid pulse
    DEBUG_Y_VALID_R    : out std_logic;                         -- Output valid flag
    DEBUG_FIFO_DATA    : out std_logic_vector(23 downto 0);    -- Current FIFO data being processed
    DEBUG_Y_OUTPUT     : out std_logic_vector(23 downto 0)     -- Current FIR output
  );
end FIR_FILTER;

architecture SIMPLE of FIR_FILTER is

  -- Types / helpers
  subtype samp_t  is unsigned(DATA_WIDTH-1 downto 0);             -- UQ24.0
  subtype coef_t  is unsigned(COEF_WIDTH-1 downto 0);             -- UQ0.8
  subtype prod_t  is unsigned(DATA_WIDTH+COEF_WIDTH-1 downto 0);  -- UQ32.8

  type delay_array is array (0 to M_TAPS-1) of samp_t;
  type coef_array  is array (0 to M_TAPS-1) of coef_t;
  type prod_array  is array (0 to M_TAPS-1) of prod_t;

  -- ceil(log2(n)) for n >= 1
  function clog2(n : natural) return natural is
    variable v : natural := n - 1;
    variable r : natural := 0;
  begin
    while v > 0 loop
      v := v / 2;
      r := r + 1;
    end loop;
    return r;
  end function;

  constant GUARD_BITS : integer := clog2(M_TAPS);  -- e.g. 3 for 8 taps
  constant ACC_WIDTH  : integer := DATA_WIDTH + COEF_WIDTH + GUARD_BITS;

  -- Control decode (signals)
  signal FIRENA    : std_logic;  -- FIRCTL(0)
  signal FIRRST    : std_logic;  -- FIRCTL(1)
  signal FIFORST   : std_logic;  -- FIRCTL(4)
  signal FIFOWEN_b : std_logic;  -- FIRCTL(5)
  signal CS_FIROUT_b : std_logic;
  -- FIFO storage (FIFOCLK domain)
  type fifo_mem_t is array (0 to FIFO_DEPTH-1) of samp_t;
  signal fifo_mem   : fifo_mem_t := (others => (others => '0'));

  signal w_ptr      : integer range 0 to FIFO_DEPTH-1 := 0;
  signal r_ptr      : integer range 0 to FIFO_DEPTH-1 := 0;
  signal fifo_count : integer range 0 to FIFO_DEPTH   := 0;

  signal FIFOEMPTY  : std_logic;
  signal FIFOFULL   : std_logic;

  -- FIFO write enable (no edge detection needed)
  signal fifo_wr_en : std_logic;

  -- handshake data buffer (written on read in FIFOCLK, read in FIRCLK)
  signal data_buf_fifo : samp_t := (others => '0');

  -- One-sample-per-FIRCLK handshake (toggle scheme)
  signal req_tog_fir   : std_logic := '0';
  signal ack_tog_fifo  : std_logic := '0';

  -- sync ack back to FIRCLK for pulse
  signal ack_fir_s0, ack_fir_s1, ack_fir_s2 : std_logic := '0';

  -- sync req into FIFOCLK
  signal req_fifo_s0, req_fifo_s1 : std_logic := '0';
  signal req_edge_fifo : std_logic := '0';

  -- outstanding request bookkeeping
  signal outstanding : std_logic;   -- in FIRCLK
  signal pending_req : std_logic := '0'; -- in FIFOCLK

  -- FIR core signals
  signal fifoin    : samp_t;  -- cast of input
  signal x_delay   : delay_array := (others => (others => '0'));
  signal h_coef    : coef_array := (others => (others => '0'));
  signal products  : prod_array := (others => (others => '0'));

  signal acc       : unsigned(ACC_WIDTH-1 downto 0) := (others => '0');
  signal y_scaled  : samp_t := (others => '0');
  signal y_output  : samp_t := (others => '0');

  -- Accepted-sample pulse (FIRCLK)
  signal sample_valid_firclk : std_logic := '0';

  -- *** MICRO FIX signals: delay valid by 1 cycle so FIROUT captures correct sample ***
  signal y_valid_d : std_logic := '0';
  signal y_valid_r : std_logic := '0';

  -- FIX: combined handshake reset. FIRRST and FIFORST each used to reset only
  -- one half of the req/ack toggle pair, so asserting one without the other
  -- desynchronised them and left 'outstanding' stuck at '1' forever.
  signal hs_rst : std_logic;
  
begin
  -- Control decode (concurrent)
  FIRENA    <= FIRCTL(0);
  FIRRST    <= FIRCTL(1);
  FIFORST   <= FIRCTL(4);
  FIFOWEN_b <= FIRCTL(5);
  CS_FIROUT_b <= CS_FIROUT;

  -- FIX: handshake reset covers both reset bits
  hs_rst <= FIRRST or FIFORST;

  -- This architecture wires eight discrete coefficient ports.
  assert M_TAPS = 8
    report "FIR_FILTER: COEF0..COEF7 are discrete ports, M_TAPS must be 8"
    severity failure;

  -- FIX: coefficient ports were never connected to anything
  h_coef(0) <= unsigned(COEF0);
  h_coef(1) <= unsigned(COEF1);
  h_coef(2) <= unsigned(COEF2);
  h_coef(3) <= unsigned(COEF3);
  h_coef(4) <= unsigned(COEF4);
  h_coef(5) <= unsigned(COEF5);
  h_coef(6) <= unsigned(COEF6);
  h_coef(7) <= unsigned(COEF7);
  -- Input cast (take LSB DATA_WIDTH bits)
  fifoin <= unsigned(FIRIN(DATA_WIDTH-1 downto 0));

  -- FIFO flags from registered count - FIXED for proper flow control
  FIFOEMPTY <= '1' when fifo_count = 0 else '0';
  -- CRITICAL: Set FIFOFULL when at capacity to prevent ASM overflow
  FIFOFULL  <= '1' when fifo_count >= FIFO_DEPTH else '0';

  -- Status register mapping with X-protection (combinational but X-safe)
  process(FIRCTL, FIFOFULL, FIFOEMPTY)
    variable firctl_safe : std_logic_vector(7 downto 0);
  begin
    -- Start with all zeros to prevent any X propagation
    firctl_safe := (others => '0');
    
    -- Only set bits to '1' if FIRCTL bits are explicitly '1' (not X or 0)
    -- This prevents X propagation while maintaining functionality
    if FIRCTL(5) = '1' then firctl_safe(5) := '1'; end if;  -- FIFOWEN
    if FIRCTL(4) = '1' then firctl_safe(4) := '1'; end if;  -- FIFORST
    if FIRCTL(1) = '1' then firctl_safe(1) := '1'; end if;  -- FIRRST
    if FIRCTL(0) = '1' then firctl_safe(0) := '1'; end if;  -- FIRENA
    
    -- Build the final status register (X-safe)
    FIRCTL_STATUS <= 
        "00"                -- [7:6] unused
      & firctl_safe(5)      -- [5] FIFOWEN (X-protected)
      & firctl_safe(4)      -- [4] FIFORST (X-protected)
      & FIFOFULL            -- [3] FIFOFULL (always safe)
      & FIFOEMPTY           -- [2] FIFOEMPTY (always safe)
      & firctl_safe(1)      -- [1] FIRRST (X-protected)
      & firctl_safe(0);     -- [0] FIRENA (X-protected)
  end process;

  -- FIFOWEN triggers write directly (MCU auto-clears FIFOWEN)
  fifo_wr_en <= FIFOWEN_b and (not FIFOFULL);

  -- FIRCLK: issue one request per cycle when FIRENA and no outstanding req
  process(FIRCLK)
  begin
    if rising_edge(FIRCLK) then
      if hs_rst = '1' then
        req_tog_fir <= '0';
      else
        if (FIRENA = '1') and (outstanding = '0') then
          req_tog_fir <= not req_tog_fir;
        end if;
      end if;
    end if;
  end process;

  -- Sync ack back into FIRCLK (3 flops) and form sample_valid pulse
  process(FIRCLK)
  begin
    if rising_edge(FIRCLK) then
      if hs_rst = '1' then
        ack_fir_s0 <= '0';
        ack_fir_s1 <= '0';
        ack_fir_s2 <= '0';
      else
        ack_fir_s0 <= ack_tog_fifo;
        ack_fir_s1 <= ack_fir_s0;
        ack_fir_s2 <= ack_fir_s1;
      end if;
    end if;
  end process;

  outstanding <= '1' when req_tog_fir /= ack_fir_s1 else '0';
  sample_valid_firclk <= ack_fir_s1 xor ack_fir_s2;

  -- *** MICRO FIX: valid pipeline so FIROUT is captured one cycle after accept ***
  process(FIRCLK)
  begin
    if rising_edge(FIRCLK) then
      if hs_rst = '1' then
        y_valid_d <= '0';
        y_valid_r <= '0';
      else
        y_valid_d <= sample_valid_firclk;  -- stage 1
        y_valid_r <= y_valid_d and FIRENA; -- stage 2 (gated by FIRENA)
      end if;
    end if;
  end process;

  -- Sync request into FIFOCLK and detect edge
  process(FIFOCLK)
  begin
    if rising_edge(FIFOCLK) then
      if hs_rst = '1' then
        req_fifo_s0 <= '0';
        req_fifo_s1 <= '0';
      else
        req_fifo_s0 <= req_tog_fir;
        req_fifo_s1 <= req_fifo_s0;
      end if;
    end if;
  end process;

  req_edge_fifo <= req_fifo_s0 xor req_fifo_s1;

  -- Unified FIFO read+write (single driver for fifo_count)

  process(FIFOCLK)
    variable inc, dec : integer;
    variable next_cnt : integer;
    variable pend_v   : std_logic;
  begin
    if rising_edge(FIFOCLK) then
      inc    := 0;
      dec    := 0;
      pend_v := pending_req;

      -- FIX: latch the request into a VARIABLE. Previously the incoming
      -- request was gated on pending_req = '0' while the completing read
      -- cleared pending_req in the same cycle, so a request arriving on that
      -- cycle could be dropped and never acknowledged.
      if req_edge_fifo = '1' then
        pend_v := '1';
      end if;

      -- write side
      if fifo_wr_en = '1' and fifo_count < FIFO_DEPTH then
        fifo_mem(w_ptr) <= fifoin;
        if w_ptr = FIFO_DEPTH-1 then
          w_ptr <= 0;
        else
          w_ptr <= w_ptr + 1;
        end if;
        inc := 1;
      end if;

      -- read side: serve at most one request per cycle
      if pend_v = '1' and fifo_count > 0 then
        data_buf_fifo <= fifo_mem(r_ptr);
        if r_ptr = FIFO_DEPTH-1 then
          r_ptr <= 0;
        else
          r_ptr <= r_ptr + 1;
        end if;
        dec          := 1;
        pend_v       := '0';
        ack_tog_fifo <= not ack_tog_fifo;
      end if;

      pending_req <= pend_v;

      next_cnt := fifo_count + inc - dec;
      if next_cnt < 0 then
        next_cnt := 0;
      elsif next_cnt > FIFO_DEPTH then
        next_cnt := FIFO_DEPTH;
      end if;
      fifo_count <= next_cnt;

      -- resets last so they dominate
      if FIFORST = '1' then          -- storage reset
        w_ptr      <= 0;
        r_ptr      <= 0;
        fifo_count <= 0;
      end if;
      if hs_rst = '1' then           -- handshake reset
        pending_req  <= '0';
        ack_tog_fifo <= '0';
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- FIR DATAPATH  (was missing entirely: x_delay, products, acc and y_scaled
  -- were declared but never driven, so FIROUT was permanently 0)
  --
  --   y[n] = ( SUM(k=0..M-1) h[k] * x[n-k] ) >> Q_PARAM
  --
  --   x : UQ24.0   h : UQ0.8   product : UQ32.8   acc : UQ32.8 + guard bits
  ----------------------------------------------------------------------------

  -- Tapped delay line, advanced once per accepted sample
  process(FIRCLK)
  begin
    if rising_edge(FIRCLK) then
      if FIRRST = '1' then
        x_delay <= (others => (others => '0'));
      elsif sample_valid_firclk = '1' then
        x_delay(0) <= data_buf_fifo;
        for k in 1 to M_TAPS-1 loop
          x_delay(k) <= x_delay(k-1);
        end loop;
      end if;
    end if;
  end process;

  -- Multipliers
  gen_products : for k in 0 to M_TAPS-1 generate
    products(k) <= x_delay(k) * h_coef(k);
  end generate gen_products;

  -- Adder tree / accumulator (combinational, GUARD_BITS headroom)
  process(products)
    variable sum_v : unsigned(ACC_WIDTH-1 downto 0);
  begin
    sum_v := (others => '0');
    for k in 0 to M_TAPS-1 loop
      sum_v := sum_v + resize(products(k), ACC_WIDTH);
    end loop;
    acc <= sum_v;
  end process;

  -- Drop the Q_PARAM fractional bits, saturate instead of wrapping
  process(acc)
  begin
    if acc(ACC_WIDTH-1 downto Q_PARAM+DATA_WIDTH) /= 0 then
      y_scaled <= (others => '1');                                   -- saturate
    else
      y_scaled <= acc(Q_PARAM+DATA_WIDTH-1 downto Q_PARAM);          -- >> Q
    end if;
  end process;


  -- *** ENHANCED: Ensure output is only updated when we have a valid sample ***
  process(FIRCLK)
  begin
    if rising_edge(FIRCLK) then
      if FIRRST = '1' then
        y_output <= (others => '0');
      else
        -- Only update output when we have a valid sample
        if y_valid_r = '1' then
          y_output <= y_scaled;
        end if;
      end if;
    end if;
  end process;

  -- Ports
  FIROUT <= x"00" & std_logic_vector(y_output);

  -- *** ENHANCED: IFG pulses only when y_output has a new valid value ***
  process(FIRCLK)
  begin
    if rising_edge(FIRCLK) then
      if FIRRST = '1' then
        FIRIFG <= '0';
      else
        -- Only pulse interrupt when we have a new valid output
        FIRIFG <= y_valid_r;
      end if;
    end if;
  end process;



  -- FIFO Status Outputs
DEBUG_FIFO_COUNT    <= std_logic_vector(to_unsigned(fifo_count, 5));
DEBUG_FIFO_EMPTY    <= FIFOEMPTY;
DEBUG_FIFO_FULL     <= FIFOFULL;
DEBUG_W_PTR         <= std_logic_vector(to_unsigned(w_ptr, 4));
DEBUG_R_PTR         <= std_logic_vector(to_unsigned(r_ptr, 4));

-- Handshake Status Outputs
DEBUG_PENDING_REQ   <= pending_req;
DEBUG_REQ_TOG_FIR  <= req_tog_fir;
DEBUG_ACK_TOG_FIFO <= ack_tog_fifo;
DEBUG_OUTSTANDING   <= outstanding;

-- FIR Processing Status Outputs
DEBUG_SAMPLE_VALID  <= sample_valid_firclk;
DEBUG_Y_VALID_R     <= y_valid_r;
DEBUG_FIFO_DATA     <= std_logic_vector(data_buf_fifo);
DEBUG_Y_OUTPUT      <= std_logic_vector(y_output);

end SIMPLE;