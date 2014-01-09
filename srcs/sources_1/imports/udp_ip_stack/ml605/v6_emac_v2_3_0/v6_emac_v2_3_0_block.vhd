--------------------------------------------------------------------------------
-- Project    : Xilinx LogiCORE Virtex-6 Embedded Tri-Mode Ethernet MAC
-- File       : v6_emac_v2_3_0_block.vhd
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
-- Description: This is the block level Verilog design for the Virtex-6
--              Embedded Tri-Mode Ethernet MAC Example Design.
--
--              This block level:
--
--              * instantiates appropriate PHY interface module (GMII/MII/RGMII)
--                as required based on the user configuration;
--
--              Please refer to the Datasheet, Getting Started Guide, and
--              the Virtex-6 Embedded Tri-Mode Ethernet MAC User Gude for further information.
--
--
--              -----------------------------------------|
--              | BLOCK LEVEL WRAPPER                    |
--              |                                        |
--              |    ---------------------               |
--              |    | V6 MAC            |               |
--              |    | CORE              |  ---------    |
--              |    |                   |  |       |    |
--            --|--->| Tx            Tx  |--|       |--->|
--              |    | AXI           PHY |  |       |    |
--              |    | I/F           I/F |  |       |    |
--              |    |                   |  | PHY   |    |
--              |    |                   |  | I/F   |    |
--              |    |                   |  |       |    |
--              |    | Rx            Rx  |  |       |    |
--              |    | AXI           PHY |  |       |    |
--            <-|----| I/F           I/F |<-|       |<---|
--              |    |                   |  ---------    |
--              |    |                   |               |
--              |    ---------------------               |
--              |                                        |
--              -----------------------------------------|
--
library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;


--------------------------------------------------------------------------------
-- The entity declaration for the block level example design.
--------------------------------------------------------------------------------

entity v6_emac_v2_3_0_block is
   port(
      gtx_clk                       : in std_logic;

      -- Receiver Interface
      ----------------------------
      rx_statistics_vector          : out std_logic_vector(27 downto 0);
      rx_statistics_valid           : out std_logic;

      rx_mac_aclk                   : out std_logic;
      rx_reset                      : out std_logic;
      rx_axis_mac_tdata             : out std_logic_vector(7 downto 0);
      rx_axis_mac_tvalid            : out std_logic;
      rx_axis_mac_tlast             : out std_logic;
      rx_axis_mac_tuser             : out std_logic;

      -- Transmitter Interface
      -------------------------------
      tx_ifg_delay                  : in std_logic_vector(7 downto 0);
      tx_statistics_vector          : out std_logic_vector(31 downto 0);
      tx_statistics_valid           : out std_logic;

      tx_reset                      : out std_logic;
      tx_axis_mac_tdata             : in std_logic_vector(7 downto 0);
      tx_axis_mac_tvalid            : in std_logic;
      tx_axis_mac_tlast             : in std_logic;
      tx_axis_mac_tuser             : in std_logic;
      tx_axis_mac_tready            : out std_logic;
      tx_collision                  : out std_logic;
      tx_retransmit                 : out std_logic;

      -- MAC Control Interface
      ------------------------
      pause_req                     : in std_logic;
      pause_val                     : in std_logic_vector(15 downto 0);

      -- Reference clock for IDELAYCTRL's
      refclk                        : in std_logic;

      -- GMII Interface
      -----------------
      gmii_txd                      : out std_logic_vector(7 downto 0);
      gmii_tx_en                    : out std_logic;
      gmii_tx_er                    : out std_logic;
      gmii_tx_clk                   : out std_logic;
      gmii_rxd                      : in std_logic_vector(7 downto 0);
      gmii_rx_dv                    : in std_logic;
      gmii_rx_er                    : in std_logic;
      gmii_rx_clk                   : in std_logic;




      -- asynchronous reset
      -----------------
      glbl_rstn                     : in std_logic;
      rx_axi_rstn                   : in std_logic;
      tx_axi_rstn                   : in std_logic

      );
end v6_emac_v2_3_0_block;

architecture TOP_LEVEL of v6_emac_v2_3_0_block is

-------------------------------------------------------------------------------
-- Component declarations for lower hierarchial level entities
-------------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -- Component Declaration for V6 Hard EMAC Core.
   -----------------------------------------------------------------------------
   component v6_emac_v2_3_0
    port(
      -- Clock signals
      ----------------------------
      gtx_clk                     : in  std_logic;

      -- Receiver Interface
      ----------------------------
      rx_axi_clk                  : in  std_logic;
      rx_reset_out                : out std_logic;
      rx_axis_mac_tdata           : out std_logic_vector(7 downto 0);
      rx_axis_mac_tvalid          : out std_logic;
      rx_axis_mac_tlast           : out std_logic;
      rx_axis_mac_tuser           : out std_logic;

      rx_statistics_vector        : out std_logic_vector(27 downto 0);
      rx_statistics_valid         : out std_logic;

      -- Transmitter Interface
      -------------------------------
      tx_axi_clk                  : in  std_logic;
      tx_reset_out                : out std_logic;
      tx_axis_mac_tdata           : in std_logic_vector(7 downto 0);
      tx_axis_mac_tvalid          : in  std_logic;
      tx_axis_mac_tlast           : in  std_logic;
      tx_axis_mac_tuser           : in  std_logic;
      tx_axis_mac_tready          : out std_logic;

      tx_retransmit               : out std_logic;
      tx_collision                : out std_logic;
      tx_ifg_delay                : in  std_logic_vector(7 downto 0);
      tx_statistics_vector        : out std_logic_vector(31 downto 0);
      tx_statistics_valid         : out std_logic;

      -- MAC Control Interface
      ------------------------
      pause_req                   : in  std_logic;
      pause_val                   : in  std_logic_vector(15 downto 0);

      -- Current Speed Indication
      ---------------------------
      speed_is_10_100             : out std_logic;

      -- Physical Interface of the core
      --------------------------------
      gmii_txd                    : out std_logic_vector(7 downto 0);
      gmii_tx_en                  : out std_logic;
      gmii_tx_er                  : out std_logic;
      gmii_rxd                    : in  std_logic_vector(7 downto 0);
      gmii_rx_dv                  : in  std_logic;
      gmii_rx_er                  : in  std_logic;


      glbl_rstn                   : in  std_logic;
      rx_axi_rstn                 : in  std_logic;
      tx_axi_rstn                 : in  std_logic

   );
   end component;

   -----------------------------------------------------------------------------
   -- Component Declaration for the GMII IOB logic
   -----------------------------------------------------------------------------
   component gmii_if
   port(
      -- Synchronous resets
      tx_reset             : in  std_logic;
      rx_reset             : in  std_logic;

      -- The following ports are the GMII physical interface: these will be at
      -- pins on the FPGA
      gmii_txd             : out std_logic_vector(7 downto 0);
      gmii_tx_en           : out std_logic;
      gmii_tx_er           : out std_logic;
      gmii_tx_clk          : out std_logic;
      gmii_rxd             : in  std_logic_vector(7 downto 0);
      gmii_rx_dv           : in  std_logic;
      gmii_rx_er           : in  std_logic;
      gmii_rx_clk          : in  std_logic;

      -- The following ports are the internal GMII connections from IOB logic
      -- to the TEMAC core
      txd_from_mac         : in  std_logic_vector(7 downto 0);
      tx_en_from_mac       : in  std_logic;
      tx_er_from_mac       : in  std_logic;
      tx_clk               : in  std_logic;
      rxd_to_mac           : out std_logic_vector(7 downto 0);
      rx_dv_to_mac         : out std_logic;
      rx_er_to_mac         : out std_logic;

      -- Receiver clock for the MAC and Client Logic
      rx_clk               : out  std_logic
   );
   end component;



  ------------------------------------------------------------------------------
  -- Component declaration for the synchronisation flip-flop pair
  ------------------------------------------------------------------------------
  component sync_block
  port (
    clk                    : in  std_logic;    -- clock to be sync'ed to
    data_in                : in  std_logic;    -- Data to be 'synced'
    data_out               : out std_logic     -- synced data
    );
  end component;


  ------------------------------------------------------------------------------
  -- Component declaration for the reset synchroniser
  ------------------------------------------------------------------------------
  component reset_sync
  port (
    reset_in               : in  std_logic;    -- Active high asynchronous reset
    enable                 : in  std_logic;
    clk                    : in  std_logic;    -- clock to be sync'ed to
    reset_out              : out std_logic     -- "Synchronised" reset signal
    );
  end component;


  ------------------------------------------------------------------------------
  -- internal signals used in this block level wrapper.
  ------------------------------------------------------------------------------

   signal idelayctrl_reset_sync           : std_logic;                    -- Used to create a reset pulse in the IDELAYCTRL refclk domain.
   signal idelay_reset_cnt                : std_logic_vector(3 downto 0); -- Counter to create a long IDELAYCTRL reset pulse.
   signal idelayctrl_reset                : std_logic;                    -- The reset pulse for the IDELAYCTRL.

   signal gmii_tx_en_int                  : std_logic;                    -- Internal gmii_tx_en signal.
   signal gmii_tx_er_int                  : std_logic;                    -- Internal gmii_tx_er signal.
   signal gmii_txd_int                    : std_logic_vector(7 downto 0); -- Internal gmii_txd signal.
   signal gmii_rx_dv_int                  : std_logic;                    -- gmii_rx_dv registered in IOBs.
   signal gmii_rx_er_int                  : std_logic;                    -- gmii_rx_er registered in IOBs.
   signal gmii_rxd_int                    : std_logic_vector(7 downto 0); -- gmii_rxd registered in IOBs.


   signal speedis10100_int                : std_logic;                    -- Asserted when speed is 10Mb/s or 100Mb/s.

   signal rx_mac_aclk_int                 : std_logic;                    -- Internal receive gmii/mii clock signal.
   signal tx_mac_aclk_int                 : std_logic;                    -- Internal transmit gmii/mii clock signal.

   signal glbl_rst                        : std_logic;
   signal gtx_resetn                      : std_logic := '0';
   signal tx_reset_int                    : std_logic;                    -- Synchronous reset in the MAC and gmii Tx domain
   signal rx_reset_int                    : std_logic;                    -- Synchronous reset in the MAC and gmii Rx domain

   signal rx_statistics_vector_int        : std_logic_vector(27 downto 0);
   signal rx_statistics_valid_int         : std_logic;
   signal tx_statistics_vector_int        : std_logic_vector(31 downto 0);
   signal tx_statistics_valid_int         : std_logic;
-------------------------------------------------------------------------------
-- Attribute declarations
-------------------------------------------------------------------------------
  attribute keep : string;
  attribute keep of tx_mac_aclk_int     : signal is "true";
  attribute keep of rx_mac_aclk_int     : signal is "true";

-------------------------------------------------------------------------------
-- Main body of code
-------------------------------------------------------------------------------

begin

   glbl_rst <= not glbl_rstn;
   gtx_resetn      <= glbl_rstn;


   -- assign outputs
   rx_reset <= rx_reset_int;
   tx_reset <= tx_reset_int;
   -- Assign the internal clock signals to output ports.
   rx_mac_aclk <= rx_mac_aclk_int;

   -----------------------------------------------------------------------------
   -- An IDELAYCTRL primitive needs to be instantiated for the Fixed Tap Delay
   -- mode of the IDELAY.
   -- All IDELAYs in Fixed Tap Delay mode and the IDELAYCTRL primitives have
   -- to be LOC'ed in the UCF file.
   -----------------------------------------------------------------------------
   dlyctrl : IDELAYCTRL
   port map (
      RDY               => open,
      REFCLK            => refclk,
      RST               => idelayctrl_reset
   );


   -- Create a synchronous reset in the IDELAYCTRL refclk clock domain.
   idelayctrl_reset_gen : reset_sync
   port map(
      clk               => refclk,
      enable            => '1',
      reset_in          => glbl_rst,
      reset_out         => idelayctrl_reset_sync
   );


   -- Reset circuitry for the IDELAYCTRL reset.

   -- The IDELAYCTRL must experience a pulse which is at least 50 ns in
   -- duration.  This is ten clock cycles of the 200MHz refclk.  Here we
   -- drive the reset pulse for 12 clock cycles.
   process (refclk)
   begin
      if refclk'event and refclk = '1' then
         if idelayctrl_reset_sync = '1' then
            idelay_reset_cnt <= "0000";
            idelayctrl_reset <= '1';
         else
            idelayctrl_reset <= '1';
            case idelay_reset_cnt is
            when "0000"  => idelay_reset_cnt <= "0001";
            when "0001"  => idelay_reset_cnt <= "0010";
            when "0010"  => idelay_reset_cnt <= "0011";
            when "0011"  => idelay_reset_cnt <= "0100";
            when "0100"  => idelay_reset_cnt <= "0101";
            when "0101"  => idelay_reset_cnt <= "0110";
            when "0110"  => idelay_reset_cnt <= "0111";
            when "0111"  => idelay_reset_cnt <= "1000";
            when "1000"  => idelay_reset_cnt <= "1001";
            when "1001"  => idelay_reset_cnt <= "1010";
            when "1010"  => idelay_reset_cnt <= "1011";
            when "1011"  => idelay_reset_cnt <= "1100";
            when "1100"  => idelay_reset_cnt <= "1101";
            when "1101"  => idelay_reset_cnt <= "1110";
            when others  => idelay_reset_cnt <= "1110";
                            idelayctrl_reset <= '0';
            end case;
         end if;
      end if;
   end process;


   tx_mac_aclk_int <= gtx_clk;


   -----------------------------------------------------------------------------
   -- Instantiate GMII Interface
   -----------------------------------------------------------------------------

   -- Instantiate the GMII physical interface logic
   gmii_interface : gmii_if
   port map (
      -- Synchronous resets
      tx_reset          => tx_reset_int,
      rx_reset          => rx_reset_int,

      -- The following ports are the GMII physical interface: these will be at
      -- pins on the FPGA
      gmii_txd          => gmii_txd,
      gmii_tx_en        => gmii_tx_en,
      gmii_tx_er        => gmii_tx_er,
      gmii_tx_clk       => gmii_tx_clk,
      gmii_rxd          => gmii_rxd,
      gmii_rx_dv        => gmii_rx_dv,
      gmii_rx_er        => gmii_rx_er,
      gmii_rx_clk       => gmii_rx_clk,

      -- The following ports are the internal GMII connections from IOB logic
      -- to the TEMAC core
      txd_from_mac      => gmii_txd_int,
      tx_en_from_mac    => gmii_tx_en_int,
      tx_er_from_mac    => gmii_tx_er_int,
      tx_clk            => tx_mac_aclk_int,
      rxd_to_mac        => gmii_rxd_int,
      rx_dv_to_mac      => gmii_rx_dv_int,
      rx_er_to_mac      => gmii_rx_er_int,

      -- Receiver clock for the MAC and Client Logic
      rx_clk            => rx_mac_aclk_int
   );




   rx_statistics_vector <= rx_statistics_vector_int;
   rx_statistics_valid  <= rx_statistics_valid_int;
   tx_statistics_vector <= tx_statistics_vector_int;
   tx_statistics_valid  <= tx_statistics_valid_int;

   -----------------------------------------------------------------------------
   -- Instantiate the V6 Hard Mac core
   -----------------------------------------------------------------------------
    v6emac_core : v6_emac_v2_3_0
    port map (

      ---------------------------------------------------------------------------
      -- Clock signals - used in rgmii and serial modes
      ---------------------------------------------------------------------------
      gtx_clk                => gtx_clk,

      ---------------------------------------------------------------------------
      -- Receiver Interface.
      ---------------------------------------------------------------------------
      rx_axi_clk             => rx_mac_aclk_int,
      rx_reset_out           => rx_reset_int,
      rx_axis_mac_tdata      => rx_axis_mac_tdata,
      rx_axis_mac_tvalid     => rx_axis_mac_tvalid,
      rx_axis_mac_tlast      => rx_axis_mac_tlast,
      rx_axis_mac_tuser      => rx_axis_mac_tuser,

      -- RX sideband signals
      rx_statistics_vector   => rx_statistics_vector_int,
      rx_statistics_valid    => rx_statistics_valid_int,

      ---------------------------------------------------------------------------
      -- Transmitter Interface
      ---------------------------------------------------------------------------
      tx_axi_clk             => tx_mac_aclk_int,
      tx_reset_out           => tx_reset_int,
      tx_axis_mac_tdata      => tx_axis_mac_tdata,
      tx_axis_mac_tvalid     => tx_axis_mac_tvalid,
      tx_axis_mac_tlast      => tx_axis_mac_tlast,
      tx_axis_mac_tuser      => tx_axis_mac_tuser,
      tx_axis_mac_tready     => tx_axis_mac_tready,

      -- TX sideband signals
      tx_retransmit          => tx_retransmit,
      tx_collision           => tx_collision,
      tx_ifg_delay           => tx_ifg_delay,
      tx_statistics_vector   => tx_statistics_vector_int,
      tx_statistics_valid    => tx_statistics_valid_int,

      ---------------------------------------------------------------------------
      -- Flow Control
      ---------------------------------------------------------------------------
      pause_req              => pause_req,
      pause_val              => pause_val,

      ---------------------------------------------------------------------------
      -- Speed interface
      ---------------------------------------------------------------------------
      speed_is_10_100        => speedis10100_int,

      ---------------------------------------------------------------------------
      -- GMII/MII Interface
      ---------------------------------------------------------------------------
      gmii_txd               => gmii_txd_int,
      gmii_tx_en             => gmii_tx_en_int,
      gmii_tx_er             => gmii_tx_er_int,
      gmii_rxd               => gmii_rxd_int,
      gmii_rx_dv             => gmii_rx_dv_int,
      gmii_rx_er             => gmii_rx_er_int,




      ---------------------------------------------------------------------------
      -- Resets
      ---------------------------------------------------------------------------

      glbl_rstn              => gtx_resetn,
      rx_axi_rstn            => rx_axi_rstn,
      tx_axi_rstn            => tx_axi_rstn

   );

end TOP_LEVEL;
