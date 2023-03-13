--------------------------------------------------------------------
--------------------------------------------------------------------
--                                                                --
--   d8888   o888                                                 --
--  d888888  O888                                ,--.""           --
--       88   88  V888888                __,----( o ))            --
--       88  88      88P               ,'--.      , (             --
--       88 88     88P          -"",:-(    o ),-'/  ;             --
--       8888    d8P              ( o) `o  _,'\ / ;(              --
--       888    888888888P         `-;_-<'\_|-'/ '  )             --
--                                     `.`-.__/ '   |             --
--                        \`.            `. .__,   ;              --
--                         )_;--.         \`       |              --
--                        /'(__,-:         )      ;               --
--                      ;'    (_,-:     _,::     .|               --
--                     ;       ( , ) _,':::'    ,;                --
--                    ;         )-,;'  `:'     .::                --
--                    |         `'  ;         `:::\               --
--                    :       ,'    '            `:\              --
--                    ;:    '  _,-':         .'     `-.           --
--                     ';::..,'  ' ,        `   ,__    `.         --
--                       `;''   / ;           _;_,-'     `.       --
--                             /            _;--.          \      --
--                           ,'            / ,'  `.         \     --
--                          /:            (_(   ,' \         )    --
--                         /:.               \_(  /-. .:::,;/     --
--                        (::..                 `-'\ "`""'        --
--------------------------------------------------------------------
--------------------------------------------------------------------
--                                                                --
--  Daniel Vazquez,  daniel.vazquez@upm.es                        --
--  25/04/22                                                      --
--                                                                --
--  Centro de Electronica Industrial (CEI)                        --
--  Universidad Politecnica de Madrid (UPM)                       --
--                                                                --
--------------------------------------------------------------------
--------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity D_EB is
    generic(
        C_RST_POL    : std_logic    := '1';
        C_DATA_WIDTH : natural      := 32        
    );
    port(
        clk     : in std_logic;
        reset   : in std_logic;
        -- Data in
        din     : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        din_v   : in std_logic;
        din_r   : out std_logic;
        -- Data out
        dout    : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        dout_v  : out std_logic;
        dout_r  : in std_logic
    );
end D_EB;

architecture Behavioral of D_EB is

    signal areg, vaux : std_logic;
    signal data_0, data_1 : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal valid_0, valid_1 : std_logic;
    
begin

    DATA_REGS : process(clk,reset)
    begin
        if reset = C_RST_POL then
        
            data_0 <= (others => '0');
            data_1 <= (others => '0');
            
        elsif clk'event and clk = '1' then
        
            if areg = '1' then
                data_0 <= din;
                data_1 <= data_0;
            end if;
        
        end if;
    end process;
    
    dout <= data_0 when areg = '1' else data_1;
    
    CONTROL_REGS : process(clk,reset)
    begin
        if reset = C_RST_POL then
        
            areg <= '0';
            valid_0 <= '0';
            valid_1 <= '0';
        
        elsif clk'event and clk = '1' then
        
            areg <= dout_r or not vaux;
            
            if areg = '1' then
                valid_0 <= din_v;
                valid_1 <= valid_0;
            end if;
            
        end if;
    end process;
    
    vaux <= valid_0 when areg = '1' else valid_1;
    dout_v <= vaux;
    din_r <= areg;
    

end Behavioral;
