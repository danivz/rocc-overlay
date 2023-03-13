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

entity FU is

    generic(
        C_RST_POL           : std_logic := '0';
        C_DATA_WIDTH        : positive  := 32;
        C_FIXED_POINT       : boolean   := false;
        C_FRACTION_LENGTH   : natural   := 16
    ); 
    port(
        clk     : in std_logic;
        reset   : in std_logic;
        
        -- Data ports
        din_1   : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        din_2   : in std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        din_v   : in std_logic;
        din_r   : out std_logic;
        dout    : out std_logic_vector(C_DATA_WIDTH - 1 downto 0);
        dout_v  : out std_logic;
        dout_r  : in std_logic;
        
        -- Config ports
        loop_source         : in std_logic_vector(1 downto 0);
        iterations_reset    : in std_logic_vector(15 downto 0);
        op_config           : in std_logic_vector(4 downto 0)
    );
    
end FU;

architecture Behavioral of FU is

    signal alu_din_1, alu_din_2, alu_dout, dout_reg : std_logic_vector(C_DATA_WIDTH - 1 downto 0);
    signal loaded, valid : std_logic;

begin

    ALU : entity work.ALU
        generic map(
            C_RST_POL           => C_RST_POL,
            C_DATA_WIDTH        => C_DATA_WIDTH,
            C_FIXED_POINT       => C_FIXED_POINT,
            C_FRACTION_LENGTH   => C_FRACTION_LENGTH       
        )
        port map(     
            din_1       => alu_din_1,
            din_2       => alu_din_2,
            dout        => alu_dout,
            op_config   => op_config
        );
        
    process(loop_source, din_1, din_2, alu_dout, dout_reg, loaded)
    begin
    
        if loop_source = "00" then
        
            alu_din_1 <= din_1;
            alu_din_2 <= din_2;
        elsif loop_source = "01" then
        
            if loaded = '0' then
                alu_din_1 <= din_1;
                alu_din_2 <= din_2;
            else
                alu_din_1 <= dout_reg;
                alu_din_2 <= din_2;
            end if;
            
        elsif loop_source = "10" then
        
            if loaded = '0' then
                alu_din_1 <= din_1;
                alu_din_2 <= din_2;
            else
                alu_din_1 <= din_1;
                alu_din_2 <= dout_reg;
            end if;

        else
        
            alu_din_1 <= (others => '1');
            alu_din_2 <= (others => '1');
            
        end if;
        
    end process;
    
    process(clk, reset)
    
        variable count  : integer range 0 to 2**16 - 1;
    
    begin
    
        if reset = C_RST_POL then
        
            loaded <= '0';
            count := 0;
            dout_reg <= (others => '0');
            valid <= '0';
            
        elsif clk'event and clk = '1' then
        
            if dout_r = '1' then
                valid <= '0';
            end if;
            
            if din_v = '1' and dout_r = '1' and (loop_source = "01" or loop_source = "10") then
                loaded <= '1';
                count := count + 1;                
            end if;
            
            if count = to_integer(unsigned(iterations_reset)) and (loop_source = "01" or loop_source = "10") and dout_r = '1' then
            
                count := 0;
                loaded <= '0';
                valid <= '1';
                dout_reg <= alu_dout;
                
            elsif (loop_source = "01" or loop_source = "10") and din_v = '1' and dout_r = '1' then
            
                dout_reg <= alu_dout;

            end if;
            
        
        end if;
    end process;
    
    dout_v <= din_v when loop_source = "00" else valid;    
    din_r <= dout_r;
    dout <= alu_dout when loop_source = "00" else dout_reg;
     
    
end Behavioral;
