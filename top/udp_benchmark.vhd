----------------------------------------------------------------------------------
-- Company: University of Padova
-- Engineer: Simone Gaiarin <gaiarins@dei.unipd.it>
--
-- Create Date: 10/25/2013 11:26:19 AM
-- Design Name:
-- Module Name: udp_benchmark - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description: This module associated with the Qt PC benchmark software is used to perform a speed test and packet loss test
--              of the underlying udp/ip module.
--              The current implementation works in an half-duplex fashion, but a full duplex version can be easily
--              obtained by splitting the main process in two process: one for the tx and one for the rx
--
--              PC>FPGA benchmark workflow:
--                1) Send one or multiple packet containing the byte 0xAA to reset the packet counter
--                2) Send a fixed number of packets with 1472 bytes of data
--                3) Require a report by sending a packet containing the byte 0xBB, the received packet
--                   report the number of correct packet received by the FPGA.
--                4) The speed is calculated by the PC software
--
--              FPGA>PC benchmark workflow:
--                1) Send one or multiple packet containing the byte 0xAA to reset the packet counter
--                2) Send one packet containing the byte 0xCC to begin the test
--                3) The speed and the packet loss is calculated by the PC software   
--
--              Note that the PC can be slower in sending and receiving packets, and this can imply some packet losses
--              Slowing the PC tx rate can avoid packet losses
--              Since the current implementation send the packets from the FPGA to the PC at the maximum rate
--              some packet losses in this direction are expected


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- UDP/IP libraries
use work.axi.all;
use work.ipv4_types.all;
use work.arp_types.all;

entity udp_benchmark is
    generic (
        -- IP and MAC of the FPGA must be set here
        our_ip_address          : std_logic_vector (31 downto 0)  :=   x"c0a80001" ;   -- 192.168.0.1    
        our_mac_address         : std_logic_vector (47 downto 0)  :=   x"002320212223"
    );
    port (
        -- System signals
        ------------------
        reset                   : in std_logic;             -- asynchronous reset
        clk_in_p                : in std_logic;             -- 200MHz clock input from board
        clk_in_n                : in std_logic;
        -- GMII Interface
        -----------------
        phy_resetn              : out std_logic;
        gmii_txd                : out std_logic_vector(7 downto 0);
        gmii_tx_en              : out std_logic;
        gmii_tx_er              : out std_logic;
        gmii_tx_clk             : out std_logic;
        gmii_rxd                : in  std_logic_vector(7 downto 0);
        gmii_rx_dv              : in  std_logic;
        gmii_rx_er              : in  std_logic;
        gmii_rx_clk             : in  std_logic;
        gmii_col                : in  std_logic;
        gmii_crs                : in  std_logic;
        mii_tx_clk              : in  std_logic
    );
end udp_benchmark;

architecture Behavioral of udp_benchmark is

    ------------------------------------------------------------------------------
    -- Component Declaration for the complete UDP layer
    ------------------------------------------------------------------------------
    component UDP_Complete is
        generic (
            CLOCK_FREQ              : integer := 125000000;     -- freq of data_in_clk -- needed to timeout cntr
            ARP_TIMEOUT             : integer := 60;            -- ARP response timeout (s)
            ARP_MAX_PKT_TMO         : integer := 5;             -- # wrong nwk pkts received before set error
            MAX_ARP_ENTRIES         : integer := 255            -- max entries in the ARP store
        );
        port (
            -- UDP TX signals
            udp_tx_start            : in std_logic;                           -- set to request a tx
            udp_txi                 : in udp_tx_type;                         -- axi out (data to tx)
            udp_tx_result           : out std_logic_vector (1 downto 0);      -- tx status (changes during transmission)
            udp_tx_data_out_ready   : out std_logic;                          -- indicates udp_tx is ready to take data
            -- UDP RX signals
            udp_rx_start            : out std_logic;                          -- indicates receipt of udp header (data available)
            udp_rxo                 : out udp_rx_type;                        -- axi in (data received)
            -- IP RX signals
            ip_rx_hdr               : out ipv4_rx_header_type;                -- header of the received pkt
            -- system signals
            clk_in_p                : in  std_logic;                          -- 200MHz clock input from board (LVDS)
            clk_in_n                : in  std_logic;                          -- 200MHz clock input from board (LVDS)
            clk_out                 : out std_logic;                          -- system wide clk (obtained from LVDS)
            reset                   : in std_logic;
            our_ip_address          : in std_logic_vector (31 downto 0);
            our_mac_address         : in std_logic_vector (47 downto 0);
            control                 : in udp_control_type;                    -- used to clear arp cache
            -- status signals
            arp_pkt_count           : out std_logic_vector(7 downto 0);       -- count of arp pkts received
            ip_pkt_count            : out std_logic_vector(7 downto 0);       -- number of IP pkts received for us
            -- GMII Interface
            phy_resetn              : out std_logic;
            gmii_txd                : out std_logic_vector(7 downto 0);
            gmii_tx_en              : out std_logic;
            gmii_tx_er              : out std_logic;
            gmii_tx_clk             : out std_logic;
            gmii_rxd                : in  std_logic_vector(7 downto 0);
            gmii_rx_dv              : in  std_logic;
            gmii_rx_er              : in  std_logic;
            gmii_rx_clk             : in  std_logic;
            gmii_col                : in  std_logic;
            gmii_crs                : in  std_logic;
            mii_tx_clk              : in  std_logic
        );
    end component;

    -- System signals
    -----------------
    signal clk_int              : std_logic;

    -- State machine signals
    -----------------
    type state_type is (RST, IDLE, SEND_DATA, RECEIVE, SEND_REPORT);  -- can be modified for your own needed
    signal state                : state_type;

    -- UDP/IP signals
    ------------------
    -- UDP TX signals
    signal udp_tx_int                   : udp_tx_type;
    signal udp_tx_start_int             : std_logic;
    signal udp_tx_result_int            : std_logic_vector(1 downto 0);
    signal udp_tx_data_out_ready_int    : std_logic;
    signal tx_hdr                       : udp_tx_header_type;       -- optional signal to simplify the notation
    signal tx_data                      : axi_out_type;             -- optional signal to simplify the notation
    -- UDP RX signals
    signal udp_rx_start_int             : std_logic;
    signal udp_rx_int                   : udp_rx_type;
    signal rx_hdr                       : udp_rx_header_type;       -- optional signal to simplify the notation
    signal rx_data                      : axi_in_type;              -- optional signal to simplify the notation
    -- IP RX signals
    signal ip_rx_hdr_int                : ipv4_rx_header_type;
    -- control signals
    signal control                      : udp_control_type;
    -- status signals
    signal arp_pkt_count_int            : std_logic_vector(7 downto 0);
    signal ip_pkt_count_int             : std_logic_vector(7 downto 0);

    -- Example signals (can be deleted)
    ----------------
    signal data_rx                      : std_logic_vector(7 downto 0);

begin

    -- follower just needed to simplify the notation
    udp_tx_int.hdr <= tx_hdr;
    udp_tx_int.data <= tx_data;
    rx_hdr <= udp_rx_int.hdr;
    rx_data <= udp_rx_int.data;--                3) Require a report by sending a packet containing the byte 0xBB, the received packet
--                   report the number of correct packet received by the FPGA.

    -- UDP internal mechanism
    tx_data.data_out_valid <= udp_tx_data_out_ready_int;    -- set the data-out-valid-flag to when the udp is ready to accept packet

    -- Main sync process (state update, output update)
    process (clk_int, reset)
        variable count      : integer := 0;          -- used to choose the byte to be sent or the place where store the byte received
        variable count_pkt  : integer := 0;          -- used to count the tx/rx packet for the benchmark
        variable num_pkt_rx : std_logic_vector(31 downto 0) := (others => '0');     -- temp variable
        variable tx_test    : std_logic := '0';      -- set to 1 to begin the FPGA>PC test
    begin
        if rising_edge(clk_int) then                    
            if reset = '1' then
                state <= RST;
            else
                case state is
                    when RST =>
                        state <= IDLE;
                        -- reset UDP signals and clear ARP cache
                        udp_tx_start_int <= '0';
                        tx_data.data_out <= (others => '0');
                        tx_data.data_out_last <= '0';
                        control.ip_controls.arp_controls.clear_cache <= '1';
                        -- reset util signals
                        count := 0;
                        -- reset benchmark signals
                        count_pkt := 0;
                        num_pkt_rx := (others => '0');
                        tx_test := '0';

                    when IDLE =>
                        if udp_rx_start_int = '1' then
                            case rx_data.data_in is
                                when x"AA" => count_pkt := 0;                  -- reset the packet count before beginning both the tests
                                when x"BB" =>                                  -- require a report on the packet received after the PC>FPGA test
                                    state <= SEND_REPORT;
                                    udp_tx_start_int <= '1';                   -- require data tx
                                    tx_hdr.dst_ip_addr <= x"c0a80002";         -- set the PC address (192.168.0.2)
                                    tx_hdr.src_port <= x"6aef";                -- set src and dst ports
                                    tx_hdr.dst_port <= x"6af0";
                                    tx_hdr.data_length <= x"0004";             -- set the number of data bytes to be tx
                                    tx_hdr.checksum <= x"0000";                -- disable udp checksum (set it to zero) (or find a way to calculate it)
                                when x"CC" => tx_test := '1';                  -- begin the FPGA>PC test
                                when others => state <= RECEIVE;               -- receive packets from the PC during the PC>FPGA test
                            end case;
                        end if;
                        if tx_test = '1' then                              -- continue to tx packet to the PC 
                            if count_pkt = 10000 then
                                tx_test := '0';
                            else
                                state <= SEND_DATA;
                                udp_tx_start_int <= '1';                   -- require data tx
                                tx_hdr.dst_ip_addr <= x"c0a80002";         -- set a the PC address (192.168.0.2)
                                tx_hdr.src_port <= x"6aef";                -- set src and dst ports
                                tx_hdr.dst_port <= x"6af0";
                                tx_hdr.data_length <= x"05c0";             -- set the number of data bytes to be tx
                                tx_hdr.checksum <= x"0000";                -- disable udp checksum (set it to zero) (or find a way to calculate it)
                            end if;
                        end if;
                        -- reset UDP signals
                        tx_data.data_out <= (others => '0');
                        tx_data.data_out_last <= '0';
                        control.ip_controls.arp_controls.clear_cache <= '0';
                        -- reset util signals
                        count := 0;

                    when RECEIVE =>
                        if udp_rx_int.data.data_in_last = '1' then                  -- when the last byte has been received the rx phase is over we get back to the IDLE state
                            count_pkt := count_pkt + 1;
                            state <= IDLE;
                        else
                            data_rx <= rx_data.data_in;                             -- read the new bytes (in this case they are stored on data_rx overwriting the previous ones)
                        end if;

                    when SEND_REPORT =>
                        if udp_tx_result_int = UDPTX_RESULT_ERR then    -- if error occurred reset to idle state or manage the error
                            udp_tx_start_int <= '0';
                            state <= IDLE; --TODO: re-QUERY_STATE
                        else
                            num_pkt_rx := std_logic_vector(to_unsigned(count_pkt, num_pkt_rx'length));

                            if udp_tx_result_int = UDPTX_RESULT_SENDING then    --reset the tx request as soon as the tx begin
                                udp_tx_start_int <= '0';
                            end if;

                            if udp_tx_data_out_ready_int = '1' then
                                count := count + 1;
                            end if;

                            case count is
                                when 0 => tx_data.data_out <= num_pkt_rx( 31 downto 24);
                                when 1 => tx_data.data_out <= num_pkt_rx( 23 downto 16);
                                when 2 => tx_data.data_out <= num_pkt_rx( 15 downto 8);
                                when 3 => tx_data.data_out <= num_pkt_rx( 7 downto 0); tx_data.data_out_last <= '1';  -- on the last tx byte data_out_last must be set
                                when others => null; state <= IDLE;
                            end case;
                        end if;

                    when SEND_DATA =>
                        if udp_tx_result_int = UDPTX_RESULT_ERR then    -- if error occurred reset to idle state or manage the error
                            udp_tx_start_int <= '0';
                            state <= IDLE; --TODO: re-QUERY_STATE
                        else
                            if udp_tx_result_int = UDPTX_RESULT_SENDING then    --reset the tx request as soon as the tx begin
                                udp_tx_start_int <= '0';
                            end if;

                            --fill the packet with dummy bytes, the last packet is filled with different bytes
                            --to mark the last packet sent by the FPGA so that the software PC can stop counting
                            if count_pkt = 9999 then
                                tx_data.data_out <= x"DD";      
                            else
                                tx_data.data_out <= x"AA";
                            end if;

                            if udp_tx_data_out_ready_int = '1' then
                                count := count + 1;
                            end if;

                            --when the last byte is sent increase the packet count
                            if count = 1471 then -- MTU=1472 (minus 1)
                                tx_data.data_out_last <= '1';
                                count_pkt := count_pkt + 1;
                                state <= IDLE;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Instantiate the UDP layer
    ------------------------------------------------------------------------------
    UDP_block : UDP_Complete
        generic map (
            ARP_TIMEOUT                 => 10        -- timeout in seconds
        )
        port map (
            -- UDP interface
            udp_tx_start                => udp_tx_start_int,
            udp_txi                     => udp_tx_int,
            udp_tx_result               => udp_tx_result_int,
            udp_tx_data_out_ready       => udp_tx_data_out_ready_int,
            -- UDP RX signals
            udp_rx_start                => udp_rx_start_int,
            udp_rxo                     => udp_rx_int,
            -- IP RX signals
            ip_rx_hdr                   => ip_rx_hdr_int,
            -- System interface
            clk_in_p                    => clk_in_p,
            clk_in_n                    => clk_in_n,
            clk_out                     => clk_int,
            reset                       => reset,
            our_ip_address              => our_ip_address,
            our_mac_address             => our_mac_address,
            control                     => control,
            -- status signals
            arp_pkt_count               => arp_pkt_count_int,
            ip_pkt_count                => ip_pkt_count_int,
            -- GMII Interface
            phy_resetn                  => phy_resetn,
            gmii_txd                    => gmii_txd,
            gmii_tx_en                  => gmii_tx_en,
            gmii_tx_er                  => gmii_tx_er,
            gmii_tx_clk                 => gmii_tx_clk,
            gmii_rxd                    => gmii_rxd,
            gmii_rx_dv                  => gmii_rx_dv,
            gmii_rx_er                  => gmii_rx_er,
            gmii_rx_clk                 => gmii_rx_clk,
            gmii_col                    => gmii_col,
            gmii_crs                    => gmii_crs,
            mii_tx_clk                  => mii_tx_clk
        );

end Behavioral;
