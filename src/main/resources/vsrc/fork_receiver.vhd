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
use IEEE.math_real.all;

entity fork_receiver is
    Generic (
        C_NUMBER_OF_VALIDS : positive;
        C_NUMBER_OF_READYS : positive
    );
    Port(
        valid_in        : in std_logic_vector(C_NUMBER_OF_VALIDS-1 downto 0);
        valid_out       : out std_logic;
        ready_out       : in std_logic_vector(C_NUMBER_OF_READYS-1 downto 0);
        valid_mux_sel   : in std_logic_vector( integer(ceil(log2(real(C_NUMBER_OF_VALIDS))))-1 downto 0);
        fork_mask       : in std_logic_vector (C_NUMBER_OF_READYS-1 downto 0)
    );
end fork_receiver;

architecture Behavioral of fork_receiver is 

    signal aux, temp : std_logic_vector (C_NUMBER_OF_READYS downto 0);
    signal Vaux : std_logic_vector (0 downto 0); 
    
begin    
    
    MASK_GEN : for i in 0 to C_NUMBER_OF_READYS - 1 generate
        aux(i) <= (not fork_mask(i)) or ready_out(i);
    end generate;

    MUX : entity work.conf_mux
        generic map(
            C_NUM_INPUTS => C_NUMBER_OF_VALIDS,
            C_DATA_WIDTH => 1
        )
        port map(
            selector    => valid_mux_sel, 
            mux_input   => valid_in, 
            mux_output  => Vaux 
        );
             
    aux(C_NUMBER_OF_READYS) <= Vaux(0);
        
    temp(0) <= aux(0);
    
    AND_GEN : for i in 1 to C_NUMBER_OF_READYS generate 
        temp(i) <= temp(i-1) and aux(i);
    end generate;   
          
    valid_out <= temp(C_NUMBER_OF_READYS);

end Behavioral;
