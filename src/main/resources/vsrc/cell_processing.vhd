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

entity cell_processing is
    generic(
        C_RST_POL           : std_logic := '1';
        C_DATA_WIDTH        : natural   := 32;
        C_FIXED_POINT       : boolean   := false;
        C_FRACTION_LENGTH   : natural   := 16
    );
    port(
        clk     : in std_logic;
        reset   : in std_logic;
        
        -- Data in
        north_din   : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        north_din_v : in std_logic;
        east_din    : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        east_din_v  : in std_logic;
        south_din   : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        south_din_v : in std_logic;
        west_din    : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        west_din_v  : in std_logic;
        FU_din_1_r  : out std_logic;
        FU_din_2_r  : out std_logic;
        
        -- Data out
        dout            : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        dout_v          : out std_logic;
        north_dout_r    : in std_logic;
        east_dout_r     : in std_logic;
        south_dout_r    : in std_logic;
        west_dout_r     : in std_logic;
        
        -- Config
        config_bits : in std_logic_vector(181 downto 0)
    );
end cell_processing;

architecture Behavioral of cell_processing is
    
    -- Config signals
    signal selector_mux_1, selector_mux_2 : std_logic_vector(2 downto 0);
    signal fork_receiver_mask_1, fork_receiver_mask_2 : std_logic_vector(3 downto 0);
    signal op_config    : std_logic_vector(4 downto 0);
    signal fork_sender_mask : std_logic_vector(4 downto 0);
    signal I1_const : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal initial_value_load : std_logic_vector(31 downto 0);
    signal iterations_reset_load, fifo_length_load : std_logic_vector(15 downto 0);
    signal load_initial_value : std_logic_vector(1 downto 0);
    
    -- Interconnect signals
    signal FU_dout, EB_din_1, EB_din_2, join_din_1, join_din_2, join_dout_1, join_dout_2 : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal FU_dout_v, FU_dout_r, EB_din_1_v, EB_din_2_v : std_logic;
    signal join_din_1_v, join_din_1_r, join_din_2_v, join_din_2_r, join_dout_v, join_dout_r, forked_dout_r : std_logic;
    
begin

    -- Configuration bits arrangement
    selector_mux_1                  <= config_bits(2 downto 0);
    selector_mux_2                  <= config_bits(5 downto 3);
    fork_receiver_mask_1            <= config_bits(17 downto 14);
    -- 2 fill bits (19 downto 18)
    fork_receiver_mask_2                      <= config_bits(23 downto 20);
    -- structure conf
    op_config                   <= config_bits(48 downto 44);
    -- 3 fill bits (50 downto 48)
    fork_sender_mask            <= config_bits(56 downto 52);
    -- structure conf
    I1_const                    <= config_bits(115 downto 84);
    initial_value_load          <= config_bits(147 downto 116);  -- SIN USAR
    -- rest of config
    fifo_length_load            <= config_bits(163 downto 148);
    iterations_reset_load       <= config_bits(179 downto 164);
    load_initial_value          <= config_bits(181 downto 180);
    
    -- Data 1 path
    FR_1 : entity work.fork_receiver
        generic map (
            C_NUMBER_OF_VALIDS => 6,
            C_NUMBER_OF_READYS => 4
        )
        port map (
            ready_out(0)    => west_dout_r,
            ready_out(1)    => south_dout_r,
            ready_out(2)    => east_dout_r,
            ready_out(3)    => north_dout_r,
            valid_in(0)     => north_din_v,
            valid_in(1)     => east_din_v,
            valid_in(2)     => south_din_v,
            valid_in(3)     => west_din_v,
            valid_in(4)     => '1',
            valid_in(5)     => FU_dout_v,
            valid_out       => EB_din_1_v,
            valid_mux_sel   => selector_mux_1,
            fork_mask       => fork_receiver_mask_1
        );
        
    MUX_1 : entity work.conf_mux 
        generic map(
            C_NUM_INPUTS => 6,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            selector    => selector_mux_1,
            mux_input   => FU_dout & I1_const & west_din & south_din & east_din & north_din,
            mux_output  => EB_din_1
        );
        
    EB_1 : entity work.D_EB
        generic map(
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset, 
            din     => EB_din_1,
            din_v   => EB_din_1_v,
            din_r   => FU_din_1_r,
            dout    => join_din_1,
            dout_v  => join_din_1_v,
            dout_r  => join_din_1_r
        );
            
    -- Data 2 path        
    FR_2 : entity work.fork_receiver
        generic map (
            C_NUMBER_OF_VALIDS => 6,
            C_NUMBER_OF_READYS => 4
        )
        port map (
            ready_out(0)    => west_dout_r,
            ready_out(1)    => south_dout_r,
            ready_out(2)    => east_dout_r,
            ready_out(3)    => north_dout_r,
            valid_in(0)     => north_din_v,
            valid_in(1)     => east_din_v,
            valid_in(2)     => south_din_v,
            valid_in(3)     => west_din_v,
            valid_in(4)     => '1',
            valid_in(5)     => FU_dout_v,
            valid_out       => EB_din_2_v,
            valid_mux_sel   => selector_mux_2,
            fork_mask       => fork_receiver_mask_2
        );
        
    MUX2 : entity work.conf_mux 
        generic map(
            C_NUM_INPUTS => 6,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            selector    => selector_mux_2,
            mux_input   => FU_dout & I1_const & west_din & south_din & east_din & north_din,
            mux_output  => EB_din_2
        );
        
    EB_2 : entity work.D_EB
        generic map(
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset, 
            din     => EB_din_2,
            din_v   => EB_din_2_v,
            din_r   => FU_din_2_r,
            dout    => join_din_2,
            dout_v  => join_din_2_v,
            dout_r  => join_din_2_r
        );
        
    -- Data out path
    JOIN_INST : entity work.join
        generic map(
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            din_1   => join_din_1,
            din_1_v => join_din_1_v,
            din_1_r => join_din_1_r,
            din_2   => join_din_2,
            din_2_v => join_din_2_v,
            din_2_r => join_din_2_r,
            dout_1  => join_dout_1,
            dout_2  => join_dout_2,
            dout_v  => join_dout_v,
            dout_r  => join_dout_r
        );
        
    FU_INST : entity work.FU
        generic map(
            C_RST_POL           => C_RST_POL,
            C_DATA_WIDTH        => C_DATA_WIDTH,
            C_FIXED_POINT       => C_FIXED_POINT,
            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
        )
        port map(
            clk     => clk,
            reset   => reset,
            din_1   => join_dout_1,
            din_2   => join_dout_2,
            din_v   => join_dout_v,
            din_r   => join_dout_r,
            dout    => FU_dout,
            dout_v  => FU_dout_v,
            dout_r  => FU_dout_r,
            loop_source         => load_initial_value,
            iterations_reset    => iterations_reset_load,
            op_config           => op_config
        );
        
    EB_OUT : entity work.D_EB
        generic map(
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset, 
            din     => FU_dout,
            din_v   => FU_dout_v,
            din_r   => FU_dout_r,
            dout    => dout,
            dout_v  => dout_v,
            dout_r  => forked_dout_r
        );       
    
    FS : entity work.fork_sender
        generic map(
            C_NUMBER_OF_READYS => 5
        )
        port map(
            ready_in        => forked_dout_r,
            ready_out(0)    => west_dout_r,
            ready_out(1)    => south_dout_r,
            ready_out(2)    => east_dout_r,
            ready_out(3)    => north_dout_r,
            ready_out(4)    => '1',
            fork_mask       => fork_sender_mask
        );
                          

end Behavioral;
