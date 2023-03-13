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
use ieee.numeric_std.all;

entity overlay_rocc is
    generic(
        C_RST_POL               : std_logic := '1';
        C_FIXED_POINT           : boolean   := false;
        C_FRACTION_LENGTH       : integer   := 16;
        C_DATA_WIDTH            : integer   := 32; 
        C_INPUT_NODES           : integer   := 8; 
        C_OUTPUT_NODES          : integer   := 8;
        C_FIFO_DEPTH            : integer   := 32
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
        data_out_ready  : in std_logic_vector(C_OUTPUT_NODES - 1 downto 0);
        
        -- Config
        cell_config : in std_logic_vector(191 downto 0)   
    );
end overlay_rocc;

architecture Behavioral of overlay_rocc is

    type data_north is array(0 to C_INPUT_NODES - 1) of std_logic_vector(C_DATA_WIDTH - 1 downto 0);
    type control_north is array(0 to C_INPUT_NODES - 1) of std_logic;
    signal north_din : data_north;
    signal north_din_v, north_din_r : control_north;
    type data_east is array(0 to C_OUTPUT_NODES -1) of std_logic_vector(C_DATA_WIDTH - 1 downto 0);
    type control_east is array(0 to C_OUTPUT_NODES - 1) of std_logic;
    signal east_dout : data_east;
    signal east_dout_v, east_dout_r : control_east;
    type interconnection_data_hor is array(0 to C_INPUT_NODES-2, 0 to C_OUTPUT_NODES-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    type interconnection_data_ver is array(0 to C_INPUT_NODES-1, 0 to C_OUTPUT_NODES-2) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    type interconnection_control_hor is array(0 to C_INPUT_NODES-2, 0 to C_OUTPUT_NODES-1) of std_logic;
    type interconnection_control_ver is array(0 to C_INPUT_NODES-1, 0 to C_OUTPUT_NODES-2) of std_logic;
    signal interc_data_we, interc_data_ew: interconnection_data_hor;
    signal interc_valid_we, interc_valid_ew : interconnection_control_hor;
    signal interc_ready_we, interc_ready_ew : interconnection_control_hor;
    signal interc_data_ns, interc_data_sn: interconnection_data_ver;
    signal interc_valid_ns, interc_valid_sn : interconnection_control_ver;
    signal interc_ready_ns, interc_ready_sn : interconnection_control_ver;
    type config_array is array(C_INPUT_NODES*C_OUTPUT_NODES-1 downto 0) of std_logic_vector(181 downto 0);
    signal config_bits : config_array;
    type catch_array is array(C_INPUT_NODES*C_OUTPUT_NODES-1 downto 0) of std_logic;
    signal catch_config : catch_array;

begin

    CONFIG_PROC : process(cell_config)
    begin
        config_bits <= ( others => (others => '0'));
        config_bits(to_integer(unsigned(cell_config(190 downto 185)))) <= cell_config(181 downto 0);
        
        catch_config <= (others => '0');
        if cell_config(191) = '1' then
            catch_config(to_integer(unsigned(cell_config(190 downto 185)))) <= '1';
        end if;
    end process;

    INPUTS_PROC : process (data_in, data_in_valid, north_din_r)
    begin
        for I in 0 to C_INPUT_NODES-1 loop
            north_din(I) <= data_in(C_DATA_WIDTH*(I+1) - 1 downto C_DATA_WIDTH*I);
            north_din_v(I) <= data_in_valid(I);
            data_in_ready(I) <= north_din_r(I);
        end loop;
    end process;

    OUTPUTS_PROC : process (east_dout, east_dout_v, data_out_ready)
    begin
        for I in 0 to C_OUTPUT_NODES-1 loop
            data_out(C_DATA_WIDTH*(I+1) - 1 downto C_DATA_WIDTH*I) <= east_dout(I);
            data_out_valid(I) <= east_dout_v(I);
            east_dout_r(I) <= data_out_ready(I);
        end loop;
    end process;


    OVERLAY_GEN_VER: for I in 0 to C_INPUT_NODES-1 generate
        OVERLAY_GEN_HOR: for J in 0 to C_OUTPUT_NODES-1 generate
            WEST_OV: if I = 0 generate
                NORTHWEST_OV: if J = 0 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => north_din(I),
                            north_din_v     => north_din_v(I),
                            north_din_r     => north_din_r(I),                                                        
                            east_din        => interc_data_we(I,J),
                            east_din_v      => interc_valid_we(I,J),
                            east_din_r      => interc_ready_we(I,J),                            
                            south_din       => interc_data_ns(I,J),
                            south_din_v     => interc_valid_ns(I,J),
                            south_din_r     => interc_ready_ns(I,J),
                            west_din        => (others => '0'),
                            west_din_v      => '0',
                            west_din_r      => open,                          
                            north_dout      => open,
                            north_dout_v    => open,
                            north_dout_r    => '0',                                                        
                            east_dout       => interc_data_ew(I,J),
                            east_dout_v     => interc_valid_ew(I,J),
                            east_dout_r     => interc_ready_ew(I,J),
                            south_dout      => interc_data_sn(I,J),
                            south_dout_v    => interc_valid_sn(I,J),
                            south_dout_r    => interc_ready_sn(I,J),
                            west_dout       => open,
                            west_dout_v     => open,
                            west_dout_r     => '0',                 
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate NORTHWEST_OV;
                
                MIDWEST_OV: if J /= 0 and J /= C_OUTPUT_NODES-1 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => interc_data_sn(I,J-1),
                            north_din_v     => interc_valid_sn(I,J-1),
                            north_din_r     => interc_ready_sn(I,J-1),                                                       
                            east_din        => interc_data_we(I,J),
                            east_din_v      => interc_valid_we(I,J), 
                            east_din_r      => interc_ready_we(I,J),                            
                            south_din       => interc_data_ns(I,J),
                            south_din_v     => interc_valid_ns(I,J),
                            south_din_r     => interc_ready_ns(I,J),
                            west_din        => (others => '0'),
                            west_din_v      => '0',
                            west_din_r      => open,                             
                            north_dout      => interc_data_ns(I,J-1),
                            north_dout_v    => interc_valid_ns(I,J-1),
                            north_dout_r    => interc_ready_ns(I,J-1),           
                            east_dout       => interc_data_ew(I,J),
                            east_dout_v     => interc_valid_ew(I,J),
                            east_dout_r     => interc_ready_ew(I,J),                            
                            south_dout      => interc_data_sn(I,J),
                            south_dout_v    => interc_valid_sn(I,J),
                            south_dout_r    => interc_ready_sn(I,J),
                            west_dout       => open,
                            west_dout_v     => open,
                            west_dout_r     => '0',
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate MIDWEST_OV;
                
                SOUTHWEST_OV: if J = C_OUTPUT_NODES-1 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => interc_data_sn(I,J-1),
                            north_din_v     => interc_valid_sn(I,J-1),
                            north_din_r     => interc_ready_sn(I,J-1),
                            east_din        => interc_data_we(I,J),  
                            east_din_v      => interc_valid_we(I,J),
                            east_din_r      => interc_ready_we(I,J),
                            south_din       => (others => '0'),
                            south_din_v     => '0',
                            south_din_r     => open,
                            west_din        => (others => '0'),
                            west_din_v      => '0',
                            west_din_r      => open,                           
                            north_dout      => interc_data_ns(I,J-1),
                            north_dout_v    => interc_valid_ns(I,J-1),
                            north_dout_r    => interc_ready_ns(I,J-1),
                            east_dout       => interc_data_ew(I,J),
                            east_dout_v     => interc_valid_ew(I,J),
                            east_dout_r     => interc_ready_ew(I,J),                            
                            south_dout      => open,
                            south_dout_v    => open,
                            south_dout_r    => '0',
                            west_dout       => open,
                            west_dout_v     => open,
                            west_dout_r     => '0',
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate SOUTHWEST_OV;
            end generate WEST_OV;
            
            MIDDLE_OV: if I /= 0 and I /= C_INPUT_NODES-1 generate
                MIDDLENORTH_OV: if J = 0 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => north_din(I),
                            north_din_v     => north_din_v(I),
                            north_din_r     => north_din_r(I),
                            east_din        => interc_data_we(I,J), 
                            east_din_v      => interc_valid_we(I,J),    
                            east_din_r      => interc_ready_we(I,J),                                
                            south_din       => interc_data_ns(I,J),
                            south_din_v     => interc_valid_ns(I,J),
                            south_din_r     => interc_ready_ns(I,J),
                            west_din        => interc_data_ew(I-1,J),
                            west_din_v      => interc_valid_ew(I-1,J), 
                            west_din_r      => interc_ready_ew(I-1,J),                          
                            north_dout      => open,
                            north_dout_v    => open,
                            north_dout_r    => '0',
                            east_dout       => interc_data_ew(I,J),
                            east_dout_v     => interc_valid_ew(I,J),
                            east_dout_r     => interc_ready_ew(I,J),                            
                            south_dout      => interc_data_sn(I,J),
                            south_dout_v    => interc_valid_sn(I,J),
                            south_dout_r    => interc_ready_sn(I,J),
                            west_dout       => interc_data_we(I-1,J),  
                            west_dout_v     => interc_valid_we(I-1,J),
                            west_dout_r     => interc_ready_we(I-1,J),                           
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate MIDDLENORTH_OV;
                
                MIDDLEMIDDLE_OV: if J /= 0 and J /= C_OUTPUT_NODES-1 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => interc_data_sn(I,J-1),
                            north_din_v     => interc_valid_sn(I,J-1),
                            north_din_r     => interc_ready_sn(I,J-1),
                            east_din        => interc_data_we(I,J), 
                            east_din_v      => interc_valid_we(I,J),   
                            east_din_r      => interc_ready_we(I,J),                               
                            south_din       => interc_data_ns(I,J),
                            south_din_v     => interc_valid_ns(I,J),
                            south_din_r     => interc_ready_ns(I,J),
                            west_din        => interc_data_ew(I-1,J),
                            west_din_v      => interc_valid_ew(I-1,J), 
                            west_din_r      => interc_ready_ew(I-1,J),                          
                            north_dout      => interc_data_ns(I,J-1),
                            north_dout_v    => interc_valid_ns(I,J-1),
                            north_dout_r    => interc_ready_ns(I,J-1),
                            east_dout       => interc_data_ew(I,J),
                            east_dout_v     => interc_valid_ew(I,J),
                            east_dout_r     => interc_ready_ew(I,J),                            
                            south_dout      => interc_data_sn(I,J),
                            south_dout_v    => interc_valid_sn(I,J),
                            south_dout_r    => interc_ready_sn(I,J), 
                            west_dout       => interc_data_we(I-1,J),  
                            west_dout_v     => interc_valid_we(I-1,J),
                            west_dout_r     => interc_ready_we(I-1,J),                           
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate MIDDLEMIDDLE_OV;
                
                MIDDLESOUTH_OV: if J = C_OUTPUT_NODES-1 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => interc_data_sn(I,J-1),
                            north_din_v     => interc_valid_sn(I,J-1),
                            north_din_r     => interc_ready_sn(I,J-1),                            
                            east_din        => interc_data_we(I,J),
                            east_din_v      => interc_valid_we(I,J),
                            east_din_r      => interc_ready_we(I,J),                             
                            south_din       => (others => '0'),  
                            south_din_v     => '0',  
                            south_din_r     => open,                                 
                            west_din        => interc_data_ew(I-1,J),
                            west_din_v      => interc_valid_ew(I-1,J),
                            west_din_r      => interc_ready_ew(I-1,J),                            
                            north_dout      => interc_data_ns(I,J-1),
                            north_dout_v    => interc_valid_ns(I,J-1),
                            north_dout_r    => interc_ready_ns(I,J-1),                            
                            east_dout       => interc_data_ew(I,J),  
                            east_dout_v     => interc_valid_ew(I,J),
                            east_dout_r     => interc_ready_ew(I,J),                             
                            south_dout      => open,
                            south_dout_v    => open,
                            south_dout_r    => '0',                            
                            west_dout       => interc_data_we(I-1,J),  
                            west_dout_v     => interc_valid_we(I-1,J), 
                            west_dout_r     => interc_ready_we(I-1,J),        
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate MIDDLESOUTH_OV;
            end generate MIDDLE_OV;
            
            EAST_OV: if I = C_INPUT_NODES-1 generate
                NORTHEAST_OV: if J = 0 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => north_din(I),
                            north_din_v     => north_din_v(I),
                            north_din_r     => north_din_r(I),
                            east_din        => (others => '0'),
                            east_din_v      => '0',
                            east_din_r      => open,
                            south_din       => interc_data_ns(I,J),
                            south_din_v     => interc_valid_ns(I,J),
                            south_din_r     => interc_ready_ns(I,J),
                            west_din        => interc_data_ew(I-1,J),
                            west_din_v      => interc_valid_ew(I-1,J),
                            west_din_r      => interc_ready_ew(I-1,J),
                            north_dout      => open,
                            north_dout_v    => open,  
                            north_dout_r    => '0',
                            east_dout       => east_dout(J),
                            east_dout_v     => east_dout_v(J),
                            east_dout_r     => east_dout_r(J),
                            south_dout      => interc_data_sn(I,J),
                            south_dout_v    => interc_valid_sn(I,J),
                            south_dout_r    => interc_ready_sn(I,J),
                            west_dout       => interc_data_we(I-1,J),  
                            west_dout_v     => interc_valid_we(I-1,J),
                            west_dout_r     => interc_ready_we(I-1,J),
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate NORTHEAST_OV;
                
                MIDDLEEAST_OV: if J /= 0 and J /= C_OUTPUT_NODES-1 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => interc_data_sn(I,J-1),
                            north_din_v     => interc_valid_sn(I,J-1),
                            north_din_r     => interc_ready_sn(I,J-1),
                            east_din        => (others => '0'),   
                            east_din_v      => '0',
                            east_din_r      => open,
                            south_din       => interc_data_ns(I,J),
                            south_din_v     => interc_valid_ns(I,J),
                            south_din_r     => interc_ready_ns(I,J),
                            west_din        => interc_data_ew(I-1,J),
                            west_din_v      => interc_valid_ew(I-1,J), 
                            west_din_r      => interc_ready_ew(I-1,J),
                            north_dout      => interc_data_ns(I,J-1),
                            north_dout_v    => interc_valid_ns(I,J-1),
                            north_dout_r    => interc_ready_ns(I,J-1),
                            east_dout       => east_dout(J), 
                            east_dout_v     => east_dout_v(J), 
                            east_dout_r     => east_dout_r(J),
                            south_dout      => interc_data_sn(I,J),
                            south_dout_v    => interc_valid_sn(I,J),
                            south_dout_r    => interc_ready_sn(I,J),
                            west_dout       => interc_data_we(I-1,J),  
                            west_dout_v     => interc_valid_we(I-1,J), 
                            west_dout_r     => interc_ready_we(I-1,J),
                            config_bits     => config_bits(I+C_INPUT_NODES*J), 
                            catch_config    => catch_config(I+C_INPUT_NODES*J) 
                        );
                end generate MIDDLEEAST_OV;
                
                MIDDLESOUTH_OV: if J = C_OUTPUT_NODES-1 generate
                    STRUCTURE_INST: entity work.processing_element
                        Generic map(
                            C_RST_POL           => C_RST_POL,
                            C_DATA_WIDTH        => C_DATA_WIDTH,
                            C_FIFO_DEPTH        => C_FIFO_DEPTH,
                            C_FIXED_POINT       => C_FIXED_POINT,
                            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
                        )
                        Port map( 
                            clk             => clk,
                            reset           => reset,
                            north_din       => interc_data_sn(I,J-1),
                            north_din_v     => interc_valid_sn(I,J-1),
                            north_din_r     => interc_ready_sn(I,J-1),
                            east_din        => (others => '0'),   
                            east_din_v      => '0',
                            east_din_r      => open, 
                            south_din       => (others => '0'),
                            south_din_v     => '0',
                            south_din_r     => open,
                            west_din        => interc_data_ew(I-1,J),
                            west_din_v      => interc_valid_ew(I-1,J),
                            west_din_r      => interc_ready_ew(I-1,J),
                            north_dout      => interc_data_ns(I,J-1),
                            north_dout_v    => interc_valid_ns(I,J-1),
                            north_dout_r    => interc_ready_ns(I,J-1),
                            east_dout       => east_dout(J),
                            east_dout_v     => east_dout_v(J),  
                            east_dout_r     => east_dout_r(J),
                            south_dout      => open,
                            south_dout_v    => open,
                            south_dout_r    => '0',
                            west_dout       => interc_data_we(I-1,J),  
                            west_dout_v     => interc_valid_we(I-1,J),
                            west_dout_r     => interc_ready_we(I-1,J),
                            config_bits     => config_bits(I+C_INPUT_NODES*J),
                            catch_config    => catch_config(I+C_INPUT_NODES*J)
                        );
                end generate MIDDLESOUTH_OV;
            end generate EAST_OV;
        end generate OVERLAY_GEN_HOR;
    end generate OVERLAY_GEN_VER;


end Behavioral;
