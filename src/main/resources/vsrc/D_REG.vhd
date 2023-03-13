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

entity D_REG is
    generic(
        C_RST_POL    : std_logic    := '1';
        C_DATA_WIDTH : natural      := 32        
    );
    port(
        clk     : in std_logic;
        reset   : in std_logic;

        din     : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        din_v   : in std_logic;
        din_r   : out std_logic;
        dout    : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        dout_v  : out std_logic;
        dout_r  : in std_logic
    );
end D_REG;

architecture Behavioral of D_REG is
    
    signal data : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal valid : std_logic;
    
begin

    process(clk, reset)
    begin 
        if reset = C_RST_POL then
        
            data <= (others => '0');
            valid <= '0';
            
        elsif clk'event and clk = '1' then
        
            if dout_r = '1' then
                data <= din;
                valid <= din_v;
            end if;
            
        end if;
    end process;
    
    dout <= data;
    dout_v <= valid;
    din_r <= dout_r;

end Behavioral;
