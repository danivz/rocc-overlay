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
--  30/06/22                                                      --
--                                                                --
--  Centro de Electronica Industrial (CEI)                        --
--  Universidad Politecnica de Madrid (UPM)                       --
--                                                                --
--------------------------------------------------------------------
--------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity dpr_overlay_rocc is
    generic(
        C_RST_POL               : std_logic := '1';
        C_DATA_WIDTH            : integer   := 32; 
        C_INPUT_NODES           : integer   := 8; 
        C_OUTPUT_NODES          : integer   := 8
    );
    Port ( 
        clk         : in std_logic;
        reset       : in std_logic;
        -- Data
        data_in         : in std_logic_vector(C_DATA_WIDTH*C_INPUT_NODES - 1 downto 0);
        data_in_valid   : in std_logic_vector(C_INPUT_NODES - 1 downto 0);
        data_in_ready   : out std_logic_vector(C_INPUT_NODES - 1 downto 0);
        data_out        : out std_logic_vector(C_DATA_WIDTH*C_OUTPUT_NODES - 1 downto 0);
        data_out_valid  : out std_logic_vector(C_OUTPUT_NODES - 1 downto 0);
        data_out_ready  : in std_logic_vector(C_OUTPUT_NODES - 1 downto 0)
    );
end dpr_overlay_rocc;

architecture Behavioral of dpr_overlay_rocc is


begin


end Behavioral;
