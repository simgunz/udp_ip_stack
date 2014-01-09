--------------------------------------------------------------------------------
-- Project    : Xilinx LogiCORE Virtex-6 Embedded Tri-Mode Ethernet MAC
-- File       : v6_emac_v2_3_0_wrapper.vhd
-- Version    : 2.3
-------------------------------------------------------------------------------
--
-- (c) Copyright 2004-2011 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
-- Description:  This is the VHDL example design for the Virtex-6
--               Embedded Tri-Mode Ethernet MAC. It is intended that this
--               example design can be quickly adapted and downloaded onto
--               an FPGA to provide a real hardware test environment.
--
--               This level:
--
--               * Instantiates the FIFO Block wrapper, containing the
--                 block level wrapper and an RX and TX FIFO with an
--                 AXI-S interface;
--
--               * Instantiates transmitter clocking circuitry
--                   -the User side of the FIFOs are clocked at gtx_clk
--                    at all times
--
--
--               * Serializes the Statistics vectors to prevent logic being
--                 optimized out
--
--               * Ties unused inputs off to reduce the number of IO
--
--               Please refer to the Datasheet, Getting Started Guide, and
--               the Virtex-6 Embedded Tri-Mode Ethernet MAC User Gude for
--               further information.
--
--
--               ---------------------------------------------------------
--               |FIFO BLOCK WRAPPER                                     |
--               |                                                       |
--               |                                                       |
--               |              -----------------------------------------|
--               |              | BLOCK LEVEL WRAPPER                    |
--               |              |    ---------------------               |
--               |              |    |   V6 EMAC CORE    |               |
--               |              |    |                   |               |
--               |              |    |                   |               |
--               |              |    |                   |               |
--               |              |    |                   |               |
--               |  ----------  |    |                   |               |
--               |  |        |  |    |                   |  ---------    |
--             --|->|        |--|--->| Tx            Tx  |--|       |--->|
--               |  |        |  |    | AXI-S         PHY |  |       |    |
--               |  |        |  |    | I/F           I/F |  |       |    |
--               |  |  AXI-S |  |    |                   |  | PHY   |    |
--               |  |  FIFO  |  |    |                   |  | I/F   |    |
--               |  |        |  |    |                   |  |       |    |
--               |  |        |  |    | Rx            Rx  |  |       |    |
--               |  |        |  |    | AX)-S         PHY |  |       |    |
--             <-|--|        |<-|----| I/F           I/F |<-|       |<---|
--               |  |        |  |    |                   |  ---------    |
--               |  ----------  |    ---------------------               |
--               |              |                                        |
--               |              -----------------------------------------|
--               --------------------------------------------------------|
--
--------------------------------------------------------------------------------

library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

--------------------------------------------------------------------------------
-- The entity declaration for the example_design level wrapper.
--------------------------------------------------------------------------------

entity v6_emac_v2_3_0_wrapper is
    port (
		-- System controls
		------------------
      glbl_rst                      : in  std_logic;	      				-- asynchronous reset
      mac_reset                   	: in  std_logic;							-- reset mac layer
      clk_in_p              			: in  std_logic;     	 				-- 200MHz clock input from board
      clk_in_n              : in  std_logic;

		-- MAC Transmitter (AXI-S) Interface
      ---------------------------------------------
      mac_tx_clock              		: out  std_logic;							-- data sampled on rising edge
      mac_tx_tdata         			: in  std_logic_vector(7 downto 0);	-- data byte to tx
      mac_tx_tvalid        			: in  std_logic;							-- tdata is valid
      mac_tx_tready        			: out std_logic;							-- mac is ready to accept data
      mac_tx_tlast         			: in  std_logic;							-- indicates last byte of frame

      -- MAC Receiver (AXI-S) Interface
      ------------------------------------------
      mac_rx_clock              		: out  std_logic;							-- data valid on rising edge
      mac_rx_tdata         			: out std_logic_vector(7 downto 0);	-- data byte received
      mac_rx_tvalid        			: out std_logic;							-- indicates tdata is valid
      mac_rx_tready        			: in  std_logic;							-- tells mac that we are ready to take data
      mac_rx_tlast         			: out std_logic;							-- indicates last byte of the trame
				
      -- GMII Interface
      -----------------
      phy_resetn            			: out std_logic;
      gmii_txd                      : out std_logic_vector(7 downto 0);
      gmii_tx_en                    : out std_logic;
      gmii_tx_er                    : out std_logic;
      gmii_tx_clk                   : out std_logic;
      gmii_rxd                      : in  std_logic_vector(7 downto 0);
      gmii_rx_dv                    : in  std_logic;
      gmii_rx_er                    : in  std_logic;
      gmii_rx_clk                   : in  std_logic;
      gmii_col                      : in  std_logic;
      gmii_crs                      : in  std_logic;
      mii_tx_clk                    : in  std_logic
    );
end v6_emac_v2_3_0_wrapper;

architecture wrapper of v6_emac_v2_3_0_wrapper is

  ------------------------------------------------------------------------------
  -- Component Declaration for the Tri-Mode EMAC core FIFO Block wrapper
  ------------------------------------------------------------------------------

   component v6_emac_v2_3_0_fifo_block
   port(
      gtx_clk                    : in  std_logic;
      -- Receiver Statistics Interface
      -----------------------------------------
      rx_mac_aclk                : out std_logic;
      rx_reset                   : out std_logic;
      rx_statistics_vector       : out std_logic_vector(27 downto 0);
      rx_statistics_valid        : out std_logic;

      -- Receiver (AXI-S) Interface
      ------------------------------------------
      rx_fifo_clock              : in  std_logic;
      rx_fifo_resetn             : in  std_logic;
      rx_axis_fifo_tdata         : out std_logic_vector(7 downto 0);
      rx_axis_fifo_tvalid        : out std_logic;
      rx_axis_fifo_tready        : in  std_logic;
      rx_axis_fifo_tlast         : out std_logic;

      -- Transmitter Statistics Interface
      --------------------------------------------
      tx_reset                   : out std_logic;
      tx_ifg_delay               : in  std_logic_vector(7 downto 0);
      tx_statistics_vector       : out std_logic_vector(31 downto 0);
      tx_statistics_valid        : out std_logic;

      -- Transmitter (AXI-S) Interface
      ---------------------------------------------
      tx_fifo_clock              : in  std_logic;
      tx_fifo_resetn             : in  std_logic;
      tx_axis_fifo_tdata         : in  std_logic_vector(7 downto 0);
      tx_axis_fifo_tvalid        : in  std_logic;
      tx_axis_fifo_tready        : out std_logic;
      tx_axis_fifo_tlast         : in  std_logic;

      -- MAC Control Interface
      --------------------------
      pause_req                  : in  std_logic;
      pause_val                  : in  std_logic_vector(15 downto 0);

      -- Reference clock for IDELAYCTRL's
      refclk                     : in  std_logic;

      -- GMII Interface
      -------------------
      gmii_txd                  : out std_logic_vector(7 downto 0);
      gmii_tx_en                : out std_logic;
      gmii_tx_er                : out std_logic;
      gmii_tx_clk               : out std_logic;
      gmii_rxd                  : in  std_logic_vector(7 downto 0);
      gmii_rx_dv                : in  std_logic;
      gmii_rx_er                : in  std_logic;
      gmii_rx_clk               : in  std_logic;

      -- asynchronous reset
      glbl_rstn                  : in  std_logic;
      rx_axi_rstn                : in  std_logic;
      tx_axi_rstn                : in  std_logic

   );
   end component;


  ------------------------------------------------------------------------------
  -- Component Declaration for the Clock generator
  ------------------------------------------------------------------------------

   component clk_wiz_v2_1
   port (
      -- Clock in ports
      CLK_IN1_P                 : in  std_logic;
      CLK_IN1_N                 : in  std_logic;
      -- Clock out ports
      CLK_OUT1                  : out std_logic;
      CLK_OUT2                  : out std_logic;
      CLK_OUT3                  : out std_logic;
      -- Status and control signals
      RESET                     : in  std_logic;
      LOCKED                    : out std_logic
   );
   end component;


  ------------------------------------------------------------------------------
  -- Component declaration for the reset synchroniser
  ------------------------------------------------------------------------------
  component reset_sync
  port (
     reset_in                   : in  std_logic;    -- Active high asynchronous reset
     enable                     : in  std_logic;
     clk                        : in  std_logic;    -- clock to be sync'ed to
     reset_out                  : out std_logic     -- "Synchronised" reset signal
  );
  end component;

  ------------------------------------------------------------------------------
  -- Component declaration for the synchroniser
  ------------------------------------------------------------------------------
  component sync_block
  port (
     clk                        : in  std_logic;
     data_in                    : in  std_logic;
     data_out                   : out std_logic
  );
  end component;

   ------------------------------------------------------------------------------
   -- Constants used in this top level wrapper.
   ------------------------------------------------------------------------------
   constant BOARD_PHY_ADDR                  : std_logic_vector(7 downto 0)  := "00000111";


   ------------------------------------------------------------------------------
   -- internal signals used in this top level wrapper.
   ------------------------------------------------------------------------------

   -- example design clocks
   signal gtx_clk_bufg                      : std_logic;
   signal refclk_bufg                       : std_logic;
   signal s_axi_aclk                        : std_logic;
   signal rx_mac_aclk                       : std_logic;


   signal phy_resetn_int                    : std_logic;

   -- resets (and reset generation)
   signal local_chk_reset                   : std_logic;
   signal chk_reset_int                     : std_logic;
   signal chk_pre_resetn                    : std_logic := '0';
   signal chk_resetn                        : std_logic := '0';
   signal local_gtx_reset                   : std_logic;
   signal gtx_clk_reset_int                 : std_logic;
   signal gtx_pre_resetn                    : std_logic := '0';
   signal gtx_resetn                        : std_logic := '0';
   signal rx_reset                          : std_logic;
   signal tx_reset                          : std_logic;

   signal dcm_locked                        : std_logic;
   signal glbl_rst_int                      : std_logic;
   signal phy_reset_count                   : unsigned(5 downto 0);
   signal glbl_rst_intn                     : std_logic;

   -- USER side RX AXI-S interface
   signal rx_fifo_clock                     : std_logic;
   signal rx_fifo_resetn                    : std_logic;
   signal rx_axis_fifo_tdata                : std_logic_vector(7 downto 0);
   signal rx_axis_fifo_tvalid               : std_logic;
   signal rx_axis_fifo_tlast                : std_logic;
   signal rx_axis_fifo_tready               : std_logic;

   -- USER side TX AXI-S interface
   signal tx_fifo_clock                     : std_logic;
   signal tx_fifo_resetn                    : std_logic;
   signal tx_axis_fifo_tdata                : std_logic_vector(7 downto 0);
   signal tx_axis_fifo_tvalid               : std_logic;
   signal tx_axis_fifo_tlast                : std_logic;
   signal tx_axis_fifo_tready               : std_logic;

   -- RX Statistics serialisation signals
   signal rx_statistics_valid               : std_logic;
   signal rx_statistics_valid_reg           : std_logic;
   signal rx_statistics_vector              : std_logic_vector(27 downto 0);
   signal rx_stats                          : std_logic_vector(27 downto 0);
   signal rx_stats_toggle                   : std_logic := '0';
   signal rx_stats_toggle_sync              : std_logic;
   signal rx_stats_toggle_sync_reg          : std_logic := '0';
   signal rx_stats_shift                    : std_logic_vector(29 downto 0);

   -- TX Statistics serialisation signals
   signal tx_statistics_valid               : std_logic;
   signal tx_statistics_valid_reg           : std_logic;
   signal tx_statistics_vector              : std_logic_vector(31 downto 0);
   signal tx_stats_shift                    : std_logic_vector(33 downto 0);

   -- Pause interface DESerialisation
   signal pause_shift                       : std_logic_vector(17 downto 0);
   signal pause_req                         : std_logic;
   signal pause_val                         : std_logic_vector(15 downto 0);



   -- signal tie offs
   signal tx_ifg_delay                      : std_logic_vector(7 downto 0) := (others => '0');    -- not used in this example
  signal int_frame_error                    : std_logic;

  attribute keep : string;
  attribute keep of gtx_clk_bufg             : signal is "true";
  attribute keep of refclk_bufg              : signal is "true";
  attribute keep of rx_statistics_valid      : signal is "true";
  attribute keep of rx_statistics_vector     : signal is "true";
  attribute keep of tx_statistics_valid      : signal is "true";
  attribute keep of tx_statistics_vector     : signal is "true";

  ------------------------------------------------------------------------------
  -- Begin architecture
  ------------------------------------------------------------------------------

begin
   ------------------------------------------------------------------------------
   -- Clock logic to generate required clocks from the 200MHz on board
   -- if 125MHz is available directly this can be removed
   ------------------------------------------------------------------------------
   clock_generator : clk_wiz_v2_1
   port map (
      -- Clock in ports
      CLK_IN1_P         => clk_in_p,
      CLK_IN1_N         => clk_in_n,
      -- Clock out ports
      CLK_OUT1          => gtx_clk_bufg,
      CLK_OUT2          => s_axi_aclk,
      CLK_OUT3          => refclk_bufg,
      -- Status and control signals
      RESET             => glbl_rst,
      LOCKED            => dcm_locked
   );

   -----------------
   -- global reset
   glbl_reset_gen : reset_sync
   port map (
      clk               => gtx_clk_bufg,
      enable            => dcm_locked,
      reset_in          => glbl_rst,
      reset_out         => glbl_rst_int
   );

   glbl_rst_intn <= not glbl_rst_int;

   -- generate the user side clocks for the axi fifos
   tx_fifo_clock <= gtx_clk_bufg;
   rx_fifo_clock <= gtx_clk_bufg;
	mac_tx_clock <= tx_fifo_clock;
	mac_rx_clock <= rx_fifo_clock;

   ------------------------------------------------------------------------------
   -- Generate resets required for the fifo side signals plus axi_lite logic
   ------------------------------------------------------------------------------
   -- in each case the async reset is first captured and then synchronised


  local_chk_reset <= glbl_rst or mac_reset;

  -----------------
  -- data check reset
   chk_reset_gen : reset_sync
   port map (
       clk              => gtx_clk_bufg,
       enable           => dcm_locked,
       reset_in         => local_chk_reset,
       reset_out        => chk_reset_int
   );

   -- Create fully synchronous reset in the gtx clock domain.
   gen_chk_reset : process (gtx_clk_bufg)
   begin
     if gtx_clk_bufg'event and gtx_clk_bufg = '1' then
       if chk_reset_int = '1' then
         chk_pre_resetn   <= '0';
         chk_resetn       <= '0';
       else
         chk_pre_resetn   <= '1';
         chk_resetn       <= chk_pre_resetn;
       end if;
     end if;
   end process gen_chk_reset;

  local_gtx_reset <= glbl_rst or rx_reset or tx_reset;

  -----------------
  -- gtx_clk reset
   gtx_reset_gen : reset_sync
   port map (
       clk              => gtx_clk_bufg,
       enable           => dcm_locked,
       reset_in         => local_gtx_reset,
       reset_out        => gtx_clk_reset_int
   );

   -- Create fully synchronous reset in the s_axi clock domain.
   gen_gtx_reset : process (gtx_clk_bufg)
   begin
     if gtx_clk_bufg'event and gtx_clk_bufg = '1' then
       if gtx_clk_reset_int = '1' then
         gtx_pre_resetn   <= '0';
         gtx_resetn       <= '0';
       else
         gtx_pre_resetn   <= '1';
         gtx_resetn       <= gtx_pre_resetn;
       end if;
     end if;
   end process gen_gtx_reset;


   -----------------
   -- PHY reset
   -- the phy reset output (active low) needs to be held for at least 10x25MHZ cycles
   -- this is derived using the 125MHz available and a 6 bit counter
   gen_phy_reset : process (gtx_clk_bufg)
   begin
     if gtx_clk_bufg'event and gtx_clk_bufg = '1' then
       if glbl_rst_intn = '0' then
         phy_resetn_int       <= '0';
         phy_reset_count      <= (others => '0');
       else
          if phy_reset_count /= "111111" then
             phy_reset_count <= phy_reset_count + "000001";
          else
             phy_resetn_int   <= '1';
          end if;
       end if;
     end if;
   end process gen_phy_reset;

   phy_resetn <= phy_resetn_int;

   -- generate the user side resets for the axi fifos
   tx_fifo_resetn <= gtx_resetn;
   rx_fifo_resetn <= gtx_resetn;

  ------------------------------------------------------------------------------
  -- Serialize the stats vectors
  -- This is a single bit approach, retimed onto gtx_clk
  -- this code is only present to prevent code being stripped..
  ------------------------------------------------------------------------------

  -- RX STATS

  -- first capture the stats on the appropriate clock
   capture_rx_stats : process (rx_mac_aclk)
   begin
      if rx_mac_aclk'event and rx_mac_aclk = '1' then
         rx_statistics_valid_reg <= rx_statistics_valid;
         if rx_statistics_valid_reg = '0' and rx_statistics_valid = '1' then
            rx_stats        <= rx_statistics_vector;
            rx_stats_toggle <= not rx_stats_toggle;
         end if;
      end if;
   end process capture_rx_stats;

   rx_stats_sync : sync_block
   port map (
      clk              => gtx_clk_bufg,
      data_in          => rx_stats_toggle,
      data_out         => rx_stats_toggle_sync
   );

 
   ------------------------------------------------------------------------------
   -- Instantiate the V6 Hard MAC core FIFO Block wrapper
   ------------------------------------------------------------------------------
   v6emac_fifo_block : v6_emac_v2_3_0_fifo_block
    port map (
      gtx_clk                       => gtx_clk_bufg,
      -- Reference clock for IDELAYCTRL's
      refclk                        => refclk_bufg,

      -- Receiver Statistics Interface
      -----------------------------------------
      rx_mac_aclk                   => rx_mac_aclk,
      rx_reset                      => rx_reset,
      rx_statistics_vector          => rx_statistics_vector,
      rx_statistics_valid           => rx_statistics_valid,

      -- Receiver => AXI-S Interface
      ------------------------------------------
      rx_fifo_clock                 => rx_fifo_clock,
      rx_fifo_resetn                => rx_fifo_resetn,
      rx_axis_fifo_tdata            => mac_rx_tdata,
      rx_axis_fifo_tvalid           => mac_rx_tvalid,
      rx_axis_fifo_tready           => mac_rx_tready,
      rx_axis_fifo_tlast            => mac_rx_tlast,

      -- Transmitter Statistics Interface
      --------------------------------------------
      tx_reset                      => tx_reset,
      tx_ifg_delay                  => tx_ifg_delay,
      tx_statistics_vector          => tx_statistics_vector,
      tx_statistics_valid           => tx_statistics_valid,

      -- Transmitter => AXI-S Interface
      ---------------------------------------------
      tx_fifo_clock                 => tx_fifo_clock,
      tx_fifo_resetn                => tx_fifo_resetn,
      tx_axis_fifo_tdata            => mac_tx_tdata,
      tx_axis_fifo_tvalid           => mac_tx_tvalid,
      tx_axis_fifo_tready           => mac_tx_tready,
      tx_axis_fifo_tlast            => mac_tx_tlast,

      -- MAC Control Interface
      --------------------------
      pause_req                     => '0',
      pause_val                     => (others => '0'),

      -- GMII Interface
      -------------------
      gmii_txd                      => gmii_txd,
      gmii_tx_en                    => gmii_tx_en,
      gmii_tx_er                    => gmii_tx_er,
      gmii_tx_clk                   => gmii_tx_clk,
      gmii_rxd                      => gmii_rxd,
      gmii_rx_dv                    => gmii_rx_dv,
      gmii_rx_er                    => gmii_rx_er,
      gmii_rx_clk                   => gmii_rx_clk,

      -- asynchronous reset
      glbl_rstn                     => glbl_rst_intn,
      rx_axi_rstn                   => '1',
      tx_axi_rstn                   => '1'

   );


end wrapper;
