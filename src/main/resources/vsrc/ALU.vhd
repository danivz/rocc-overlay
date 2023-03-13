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

entity ALU is

    Generic (
        C_RST_POL               : std_logic := '0';
        C_DATA_WIDTH            : positive  := 32;
        C_FIXED_POINT           : boolean   := false;
        C_FRACTION_LENGTH       : natural   := 16
    );
    Port (
        din_1       : in std_logic_vector(C_DATA_WIDTH - 1 downto 0); 
        din_2       : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        dout        : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        op_config   : in std_logic_vector(4 downto 0)
    );
    
end ALU;

architecture Behavioral of ALU is

    signal out_aux : std_logic_vector(2*C_DATA_WIDTH-1 downto 0);
    
begin
    
    INT: if C_FIXED_POINT = false generate
    begin
        process(op_config, din_1, din_2)
        begin           
            -- Operation
            case to_integer(unsigned(op_config)) is 
                when 0 =>
                    -- Sum
                    out_aux <= std_logic_vector(resize(signed(din_1) + signed(din_2), out_aux'length));
                when 1 =>
                    -- Mul
                    out_aux <= std_logic_vector(signed(din_1) * signed(din_2));
                when 2 =>
                    -- Sub
                    out_aux <= std_logic_vector(resize(signed(din_1) - signed(din_2), out_aux'length));
                when 3 =>
                    -- Shift left logical
                    out_aux <= std_logic_vector(resize(shift_left(signed(din_1),to_integer(signed(din_2))), out_aux'length));
                when 4 => 
                    -- Shift right arithmetic (Div of 2)
                    out_aux <= std_logic_vector(resize(din_1(C_DATA_WIDTH-1) & resize(shift_right(unsigned(din_1),to_integer(signed(din_2))), C_DATA_WIDTH-1), out_aux'length));
                when 5 => 
                    -- Shift right logical
                    out_aux <= std_logic_vector(resize(shift_right(signed(din_1),to_integer(signed(din_2))), out_aux'length));
                when 6 =>
                    -- And
                    out_aux <= std_logic_vector(resize(signed(din_1 and din_2), out_aux'length));
                when 7 =>
                    -- Or
                    out_aux <= std_logic_vector(resize(signed(din_1 or din_2), out_aux'length));
                when 8 =>
                    -- Xor
                    out_aux <= std_logic_vector(resize(signed(din_1 xor din_2), out_aux'length));
                when 9 =>
                    -- Div (NOT IMPLEMENTED)
                    out_aux <= (others => '0');
                when others =>
                    out_aux <= (others => '0');
            end case;
        end process;
        
        dout <= std_logic_vector(resize(signed(out_aux), dout'length));
    end generate;
    
    FI: if C_FIXED_POINT = true generate
        signal mul_sign : std_logic;
    begin
        process(op_config)
        begin           
            -- Operation
            case to_integer(unsigned(op_config)) is 
                when 0 =>
                    -- Sum
                    out_aux <= std_logic_vector(resize(signed(din_1) + signed(din_2), out_aux'length));
                when 1 =>
                    -- Mul
                    out_aux <= std_logic_vector(shift_right(signed(din_1) * signed(din_2), C_FRACTION_LENGTH));
                when 2 =>
                    -- Sub
                    out_aux <= std_logic_vector(resize(signed(din_1) - signed(din_2), out_aux'length));
                when 3 =>
                    -- Shift left logical
                    out_aux <= std_logic_vector(resize(shift_left(signed(din_1),to_integer(signed(din_2))), out_aux'length));
                when 4 => 
                    -- Shift right arithmetic (Div of 2)
                    out_aux <= std_logic_vector(resize(din_1(C_DATA_WIDTH-1) & resize(shift_right(unsigned(din_1),to_integer(signed(din_2))), C_DATA_WIDTH-1), out_aux'length));
                when 5 => 
                    -- Shift right logical
                    out_aux <= std_logic_vector(resize(shift_right(signed(din_1),to_integer(signed(din_2))), out_aux'length));
                when 6 =>
                    -- And
                    out_aux <= std_logic_vector(resize(signed(din_1 and din_2), out_aux'length));
                when 7 =>
                    -- Or
                    out_aux <= std_logic_vector(resize(signed(din_1 or din_2), out_aux'length));
                when 8 =>
                    -- Xor
                    out_aux <= std_logic_vector(resize(signed(din_1 xor din_2), out_aux'length));
                when 9 =>
                    -- Div (NOT IMPLEMENTED)
                    out_aux <= (others => '0');
                when others =>
                    out_aux <= (others => '0');
            end case; 
        end process;
        
        dout <= std_logic_vector(resize(signed(out_aux), dout'length));
  
    end generate;

end Behavioral;
