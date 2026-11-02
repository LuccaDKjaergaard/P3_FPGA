
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity XADC_reader is
    Port (
        sysclk : in STD_LOGIC;
        xa_p   : in STD_LOGIC;
        xa_n   : in STD_LOGIC;
        data_diode : out STD_LOGIC_VECTOR(11 downto 0) := (others => '0')
    );
end XADC_reader;

architecture Behavioral of XADC_reader is

    -- signals to connect with XADC
    signal eoc  : STD_LOGIC;
    signal dready : STD_LOGIC;
    signal data : STD_LOGIC_VECTOR(15 downto 0); --16 bit output from ADC
    
    signal adc_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); -- 12 bit output to system

    -- XADC IP Core
    -- initialise needed ports from XADC wizard
    -- MUST be same names as in wizard
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

begin

    -- XADC IP Core
    -- map XADC wizard pins to needed values or signals
    XADC_inst : xadc_wiz_0
        port map (
            dclk_in  => sysclk,
            daddr_in => "0010100",
            den_in   => eoc,
            di_in    => (others => '0'),
            dwe_in   => '0',
            reset_in => '0',

            vauxp4   => xa_p, --ADC[0]
            vauxn4   => xa_n, --ADC[0]
            vp_in    => '0',
            vn_in    => '0',

            do_out   => data,
            drdy_out => dready, --ready flag
            eoc_out  => eoc
        );

    -- save ADC output
    process(sysclk)
    begin
        if rising_edge(sysclk) then
            if dready = '1' then
                adc_value <= data(15 downto 4); --12 MSB passed on
                data_diode <= adc_value; --show on LEDs
            end if;
        end if;
    end process;

end Behavioral;
