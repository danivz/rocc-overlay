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

entity fork_sender is
    generic(
        C_NUMBER_OF_READYS : positive
    );
    port(
        ready_in    : out std_logic;
        ready_out   : in std_logic_vector(C_NUMBER_OF_READYS-1 downto 0);
        fork_mask   : in std_logic_vector(C_NUMBER_OF_READYS-1 downto 0)
    );
end fork_sender;

architecture Behavioral of fork_sender is

    signal aux, temp : std_logic_vector(C_NUMBER_OF_READYS-1 downto 0);

begin

    MASK_GEN : for i in 0 to C_NUMBER_OF_READYS - 1 generate
        aux(i) <= (not fork_mask(i)) or ready_out(i);
    end generate;
    
    temp(0) <= aux(0);
    
    AND_GEN : for i in 1 to C_NUMBER_OF_READYS-1 generate 
        temp(i) <= temp(i-1) and aux(i);
    end generate;   

    ready_in <= temp(C_NUMBER_OF_READYS-1);

end Behavioral;
