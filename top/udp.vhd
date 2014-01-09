----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 10/24/2013 01:12:05 PM
-- Design Name:
-- Module Name: udp - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: The UDP/IP block can work in a duplex fashion (this require two sync process)
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- UDP/IP libraries
use work.axi.all;
use work.ipv4_types.all;
use work.arp_types.all;

entity udp is
    generic (
        our_ip_address          : std_logic_vector (31 downto 0)  :=   x"c0a80002" ;   -- 192.168.0.2    -- IP and MAC of the FPGA must be set here
        our_mac_address         : std_logic_vector (47 downto 0)  :=   x"002320212223"
    );
    port (
        -- System signals
        ------------------
        reset                   : in std_logic;             -- asynchronous reset
        clk_in_p                : in std_logic;             -- 200MHz clock input from board
        clk_in_n                : in std_logic;
        clk_out                 : out std_logic;            -- 125 MHz clock out
        -- example signals (can be deleted)
        display                 : out std_logic_vector(3 downto 0);
        pbtx                    : in std_logic;
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
end udp;

architecture Behavioral of udp is

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
    type state_type is (RST, IDLE, RECEIVE, RECEIVE_AND_STORE, RECEIVE_AND_RESPOND, SEND);  -- can be modified for your own needed
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
    signal data_rx_1, data_rx_2, data_rx_3 : std_logic_vector(7 downto 0);

begin

    --Signal followers for UDP
    clk_out <= clk_int;
    -- follower just needed to simplify the notation
    udp_tx_int.hdr <= tx_hdr;
    udp_tx_int.data <= tx_data;
    rx_hdr <= udp_rx_int.hdr;
    rx_data <= udp_rx_int.data;

    -- UDP internal mechanism
    tx_data.data_out_valid <= udp_tx_data_out_ready_int;    -- set the data-out-valid-flag to when the udp is ready to accept packet

    -- Main sync process (state update, output update)
    process (clk_int, reset)
        variable count : integer := 0;          -- used to choose the byte to be sent or the place where store the byte received
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
                        -- reset example signals (can be deleted)
                        display <= "1111";

                    when IDLE =>
                        -- wait for a packet from the pc, read the first byte to choose the next state
                        if udp_rx_start_int = '1' then                              -- when udp_rx_start is 1 the first byte of data is ready to be read
                            data_rx <= rx_data.data_in;                             -- read the first byte of data and store it somewhere (optional)
                            case rx_data.data_in is                                 -- take a proper action as a function of the first byte received (this is optional, we can just receive and store the data e.g. see "others" case)
                                when x"AA"  => state <= RECEIVE_AND_STORE;
                                when x"BB"  => state <= RECEIVE_AND_RESPOND;
                                when others => state <= RECEIVE;
                            end case;
                        end if;
                        -- simulate a spontaneous transmission from the FPGA (without receiving nothing from the PC, we use a push button as a trigger)
                        if pbtx = '1' then    -- debounce mechanism has not been implemented, so many packets will be sent
                            state <= SEND;
                            udp_tx_start_int <= '1';                   -- require data tx
                            tx_hdr.dst_ip_addr <= x"c0a80002";         -- set a generic ip adrress (192.168.0.2)
                            tx_hdr.src_port <= x"6aef";                -- set src and dst ports
                            tx_hdr.dst_port <= x"6af0";
                            tx_hdr.data_length <= x"0004";             -- set the number of data bytes to be tx
                            tx_hdr.checksum <= x"0000";                -- disable udp checksum (set it to zero) (or find a way to calculate it)
                        end if;
                        -- reset UDP signals
                        tx_data.data_out <= (others => '0');
                        tx_data.data_out_last <= '0';
                        control.ip_controls.arp_controls.clear_cache <= '0';
                        -- reset util signals
                        count := 0;

                    when RECEIVE =>
                        display <= "0001";
                        if udp_rx_int.data.data_in_last = '1' then                  -- when the last byte has been received the rx phase is over we get back to the IDLE state
                            state <= IDLE;
                        else
                            data_rx <= rx_data.data_in;                             -- read the new bytes (in this case they are stored on data_rx overwriting the previous ones)
                        end if;

                    when RECEIVE_AND_STORE =>           -- in this case we expect to receive exactly 4 bytes of data (one has already been read in the IDLE state)
                        display <= "0010";
                        case count is
                            when 0 => data_rx_1    <= rx_data.data_in (7 downto 0);
                            when 1 => data_rx_2    <= rx_data.data_in (7 downto 0);
                            when 2 => data_rx_3    <= rx_data.data_in (7 downto 0); state <= IDLE; -- here an optional check on data_in_last can be added to check if this is actually the last byte
                            when others => null;
                        end case;
                        count := count + 1;

                    when RECEIVE_AND_RESPOND =>
                        display <= "0100";
                        if udp_rx_int.data.data_in_last = '1' then                  -- when the last byte has been received the rx phase is over and we are ready to tx
                            state <= SEND;
                            udp_tx_start_int <= '1';                        -- require data tx
                            tx_hdr.dst_ip_addr <= rx_hdr.src_ip_addr;       -- set dst ip address to reply to sender
                            tx_hdr.src_port <= x"6aef";                     -- set src and dst ports
                            tx_hdr.dst_port <= x"6af0";
                            tx_hdr.data_length <= x"0004";                  -- set the number of data bytes to be tx
                            tx_hdr.checksum <= x"0000";                     -- disable udp checksum (set it to zero)
                        else
                            data_rx <= rx_data.data_in;                     -- read the new bytes (in this case they are stored on data_rx overwriting the previous ones)
                        end if;

                    when SEND =>
                        display(1 downto 0) <= "00"; display(3) <= '1';
                        if udp_tx_result_int = UDPTX_RESULT_ERR then    -- if error occurred reset to idle state or manage the error
                            udp_tx_start_int <= '0';
                            state <= IDLE; --TODO: re-QUERY_STATE
                        else
                            if udp_tx_result_int = UDPTX_RESULT_SENDING then    --reset the tx request as soon as the tx begin
                                udp_tx_start_int <= '0';
                            end if;

                            -- until udp_tx_data_out_ready is zero and so data_valid flag (that means the mac is sending the udp header,
                            -- etc) no user data is tx, but data_out is already setted to the first byte to be tx
                            -- as soon as udp_tx_data_out_ready_int become equal to 1 the first byte is sent before the increment of count
                            if udp_tx_data_out_ready_int = '1' then
                                count := count + 1;
                            end if;

                            case count is
                                when 0 => tx_data.data_out <= data_rx;
                                when 1 => tx_data.data_out <= data_rx_1;
                                when 2 => tx_data.data_out <= data_rx_2;
                                when 3 => tx_data.data_out <= data_rx_3; tx_data.data_out_last <= '1'; state <= IDLE;  -- on the last tx byte data_out_last must be set
                                when others => null;
                            end case;
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
