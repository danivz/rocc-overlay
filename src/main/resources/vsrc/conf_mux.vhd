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
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

entity conf_mux is
    generic(
        C_NUM_INPUTS : positive := 2;
        C_DATA_WIDTH : positive := 1
    );
    port(
        selector    : in std_logic_vector( integer(ceil(log2(real(C_NUM_INPUTS)))) - 1 downto 0);
        mux_input   : in std_logic_vector(C_NUM_INPUTS*C_DATA_WIDTH-1 downto 0);
        mux_output  : out std_logic_vector ( C_DATA_WIDTH - 1 downto 0)
    );
end conf_mux;

architecture Behavioral of conf_mux is

    type pack is array(integer range 0 to C_NUM_INPUTS-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal inputs : pack;

begin

    ARG_GEN: for i in 0 to C_NUM_INPUTS-1 generate
    begin
        inputs(i) <= mux_input((i+1)*C_DATA_WIDTH-1 downto i*C_DATA_WIDTH);
    end generate;

    mux_output <= inputs(to_integer(unsigned(selector)));

end Behavioral;
