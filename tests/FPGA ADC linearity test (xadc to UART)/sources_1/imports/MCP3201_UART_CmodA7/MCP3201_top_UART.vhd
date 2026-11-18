
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Input: values from XADC on FPGA board 
-- UART goes through the onboard USB interface (FPGA pin J18).
-- Output: one four-digit decimal ADC value (with leading zeros if needed) per line
-- Serial terminal: 115200 baud, 8 data bits, no parity, 1 stop bit.
entity xadc_uart_top is
    Port (
        sysclk   : in  STD_LOGIC;  -- 12 MHz onboard clock
        uart_tx  : out STD_LOGIC;
        xadc_p   : in STD_LOGIC;
        xadc_n   : in STD_LOGIC
    );
end xadc_uart_top;

architecture Behavioral of xadc_uart_top is
    -- signals to connect with XADC
    signal eoc  : STD_LOGIC;
    signal data_ready : STD_LOGIC; --will be initialised by xadc
    signal value_ready : STD_LOGIC := '0';
    signal xadc_data : STD_LOGIC_VECTOR(15 downto 0); --16 bit output from ADC
    signal adc_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); -- 12 bit output to system

    -- initialise needed ports from XADC wizard
    -- port names MUST be the same as in the wizard
    component xadc_wiz_0
        Port (
            daddr_in : in STD_LOGIC_VECTOR(6 downto 0);
            dclk_in  : in STD_LOGIC;
            den_in   : in STD_LOGIC;
            di_in    : in STD_LOGIC_VECTOR(15 downto 0);
            dwe_in   : in STD_LOGIC;
            reset_in : in STD_LOGIC;
            vauxp4   : in STD_LOGIC;
            vauxn4   : in STD_LOGIC;
            vp_in    : in STD_LOGIC;
            vn_in    : in STD_LOGIC;
            do_out   : out STD_LOGIC_VECTOR(15 downto 0);
            drdy_out : out STD_LOGIC;
            eoc_out  : out STD_LOGIC
        );
    end component;

    -- 12 MHz / 104 = 115384 baud (0.16% from 115200 baud).
    constant BAUD_DIV : integer := 104;
    signal baud_count  : integer range 0 to BAUD_DIV - 1 := 0;
    signal tx_busy     : STD_LOGIC := '0';
    signal tx_shift    : STD_LOGIC_VECTOR(9 downto 0) := (others => '1');
    signal tx_bit      : integer range 0 to 9 := 0;
    signal tx_char     : integer range 0 to 5 := 0;
    signal tx_value    : integer range 0 to 4095 := 0;

    -- Function for converting decimal value into ascii
    -- Returns the ascii value of "0000", CR or LF
    function ascii_byte(n : integer; value : integer)
        return STD_LOGIC_VECTOR is
        variable c : integer;
    begin
        case n is
            when 0 => c := 48 + (value / 1000); --48 = 0 in ASCII
            when 1 => c := 48 + (value / 100) mod 10;
            when 2 => c := 48 + (value / 10) mod 10;
            when 3 => c := 48 + value mod 10;
            when 4 => c := 13;  -- carriage return (CR)
            when others => c := 10;  -- line feed (LF)
        end case;
        return STD_LOGIC_VECTOR(to_unsigned(c, 8));
    end function;

begin
    -- map XADC wizard pins to needed values or signals
    XADC_inst : xadc_wiz_0
        port map (
            dclk_in  => sysclk,
            daddr_in => "0010100",
            den_in   => eoc,
            di_in    => (others => '0'),
            dwe_in   => '0',
            reset_in => '0',

            vauxp4   => xadc_p, --vaux4 pair
            vauxn4   => xadc_n, --vaux4 pair
            vp_in    => '0',
            vn_in    => '0',

            do_out   => xadc_data,
            drdy_out => data_ready, --ready flag
            eoc_out  => eoc
        );

    -- save ADC output and pulse UART
    process(sysclk)
    begin
        if rising_edge(sysclk) then
            if data_ready = '1' then
                adc_value <= xadc_data(15 downto 4); --12 MSB passed on
                value_ready <= '1';
            else
                value_ready <= '0';
            end if;
        end if;
    end process;

    uart_tx <= tx_shift(0);  -- UART idle = logic high, tx_shift is initialised high
    -- UART transmitter: 1 start bit, 8 data bits (LSB first), 1 stop bit.
    -- Six characters per reading: e.g. "2048" + CR + LF.
    process(sysclk)
    begin
        if rising_edge(sysclk) then
            if tx_busy = '0' then
                if value_ready = '1' then
                    tx_value   <= to_integer(unsigned(adc_value)); --value to send before new adc value is pulled in
                    tx_shift   <= '1' & ascii_byte(0,
                        to_integer(unsigned(adc_value))) & '0';
                    tx_char    <= 0; --index for character currently being sent
                    tx_bit     <= 0; --index for bits shifted on tx line for current number
                    baud_count <= 0;
                    tx_busy    <= '1';
                end if;
            else --if tx_busy = '1' then
                if baud_count = BAUD_DIV - 1 then
                    baud_count <= 0; --reset baud counter

                    if tx_bit = 9 then --if we have shifted all bits
                        if tx_char = 5 then --if we have shifted all characters
                            tx_shift <= (others => '1');
                            tx_busy <= '0';
                        else --if tx_char < 5
                            tx_shift <= '1' & ascii_byte(tx_char + 1, tx_value) & '0';
                            tx_char  <= tx_char + 1;
                            tx_bit   <= 0;
                        end if;
                    else
                        tx_shift <= '1' & tx_shift(9 downto 1); --shift to the right so LSB is pushed out
                        tx_bit <= tx_bit + 1; --ready to shift again
                    end if;
                else
                    baud_count <= baud_count + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
