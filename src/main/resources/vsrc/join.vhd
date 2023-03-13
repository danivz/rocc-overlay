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

entity join is

    generic(
        C_DATA_WIDTH : positive := 32
    ); 
    port(
        -- Separate inputs
        din_1   : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        din_1_v : in std_logic;
        din_1_r : out std_logic;
        din_2   : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        din_2_v : in std_logic;
        din_2_r : out std_logic;
        
        -- Joined outputs
        dout_1  : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        dout_2  : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        dout_v  : out std_logic;
        dout_r  : in std_logic
    );
    
end join;

architecture Behavioral of join is
begin

    dout_v <= din_1_v and din_2_v;
    din_1_r <= dout_r and din_2_v;
    din_2_r <= dout_r and din_1_v;
    dout_1 <= din_1;
    dout_2 <= din_2; 
    
end Behavioral;
