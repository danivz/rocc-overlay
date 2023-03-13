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

entity processing_element is
    generic(
        C_RST_POL           : std_logic := '1';
        C_DATA_WIDTH        : natural   := 32;
        C_FIFO_DEPTH        : natural   := 32;
        C_FIXED_POINT       : boolean   := false;
        C_FRACTION_LENGTH   : natural   := 16
    );
    port(
        clk         : in std_logic;
        reset       : in std_logic;
        
        -- Data in
        north_din   : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        north_din_v : in std_logic;
        north_din_r : out std_logic;
        east_din    : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        east_din_v  : in std_logic;
        east_din_r  : out std_logic;
        south_din   : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        south_din_v : in std_logic;
        south_din_r : out std_logic;
        west_din    : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        west_din_v  : in std_logic;
        west_din_r  : out std_logic;
        
        -- Data out
        north_dout   : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        north_dout_v : out std_logic;
        north_dout_r : in std_logic;
        east_dout    : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        east_dout_v  : out std_logic;
        east_dout_r  : in std_logic;
        south_dout   : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        south_dout_v : out std_logic;
        south_dout_r : in std_logic;
        west_dout    : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        west_dout_v  : out std_logic;
        west_dout_r  : in std_logic;
        
        -- Config
        config_bits  : in std_logic_vector(181 downto 0);
        catch_config : in std_logic
    );          
end processing_element;

architecture Behavioral of processing_element is

    -- Config signals
    signal mux_N_sel, mux_E_sel, mux_S_sel, mux_W_sel : std_logic_vector(1 downto 0);
    signal accept_mask_frN, accept_mask_frE, accept_mask_frS, accept_mask_frW : std_logic_vector(4 downto 0);
    signal accept_mask_fsiN, accept_mask_fsiE, accept_mask_fsiS, accept_mask_fsiW : std_logic_vector(4 downto 0);
    signal config_bits_reg : std_logic_vector(181 downto 0);
    
    -- Interconnect signals
    -- FIFO signals
    signal north_buffer, east_buffer, south_buffer, west_buffer : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal north_buffer_v, east_buffer_v, south_buffer_v, west_buffer_v : std_logic;
    signal north_buffer_r, east_buffer_r, south_buffer_r, west_buffer_r : std_logic;
    -- REG signals
    signal north_REG_din, east_REG_din, south_REG_din, west_REG_din : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal north_REG_din_v, east_REG_din_v, south_REG_din_v, west_REG_din_v : std_logic;
    signal north_REG_din_r, east_REG_din_r, south_REG_din_r, west_REG_din_r : std_logic;
    -- Cell processing signals
    signal FU_din_1_r, FU_din_2_r : std_logic;
    signal FU_dout : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal FU_dout_v, FU_dout_r : std_logic;

begin

    REG_CONFIG : process(clk, reset)
    begin
        if reset = C_RST_POL then
            config_bits_reg  <= (others => '0');
        elsif clk'event and clk = '1' then
            if catch_config = '1' then
                config_bits_reg <= config_bits;
            end if;            
        end if;
    end process;

    -- Configuration bits arrangement
    mux_N_sel      <= config_bits_reg(7 downto 6);
    mux_E_sel      <= config_bits_reg(9 downto 8);
    mux_S_sel      <= config_bits_reg(11 downto 10);
    mux_W_sel      <= config_bits_reg(13 downto 12);
    -- cell_interior conf
    accept_mask_fsiN    <= config_bits_reg(28 downto 24);
    accept_mask_fsiE    <= config_bits_reg(33 downto 29);
    accept_mask_fsiS    <= config_bits_reg(38 downto 34);
    accept_mask_fsiW    <= config_bits_reg(43 downto 39);
    -- cell_interior conf
    accept_mask_frN     <= config_bits_reg(61 downto 57);
    accept_mask_frE     <= config_bits_reg(66 downto 62);
    accept_mask_frS     <= config_bits_reg(71 downto 67);
    accept_mask_frW     <= config_bits_reg(76 downto 72);

    ------------------------------- NORTH NODE -------------------------------
    -- North node input
    
    FIFO_Nin : entity work.D_FIFO
        Generic map (
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH,
            C_FIFO_DEPTH    => C_FIFO_DEPTH
        )
        port map (
            clk     => clk,
            reset   => reset,
            din     => north_din,
            din_v   => north_din_v,
            din_r   => north_din_r,
            dout    => north_buffer,
            dout_v  => north_buffer_v,
            dout_r  => north_buffer_r
        );
        
    FS_Nin : entity work.fork_sender
        generic map (
            C_NUMBER_OF_READYS => 5
        )
        port map(
            ready_in        => north_buffer_r,
            ready_out(0)    => west_REG_din_r,
            ready_out(1)    => south_REG_din_r,
            ready_out(2)    => east_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            fork_mask       => accept_mask_fsiN
        );  

    -- North node output
    
    MUX_Nout : entity work.conf_mux 
        generic map(
            C_NUM_INPUTS => 4,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            selector    => mux_N_sel,
            mux_input   => west_buffer & south_buffer & east_buffer & FU_dout, 
            mux_output  => north_REG_din
        );
        
    FR_Nout : entity work.fork_receiver                                  
        generic map (
            C_NUMBER_OF_VALIDS => 4,
            C_NUMBER_OF_READYS => 5
        )
        port map ( 
            ready_out(0)    => west_REG_din_r,
            ready_out(1)    => south_REG_din_r,
            ready_out(2)    => east_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            valid_in(0)     => FU_dout_v,
            valid_in(1)     => east_buffer_v,
            valid_in(2)     => south_buffer_v,
            valid_in(3)     => west_buffer_v,
            valid_out       => north_REG_din_v,
            valid_mux_sel   => mux_N_sel,
            fork_mask       => accept_mask_frN
        );        
        
    REG_Nout : entity work.D_REG
        generic map(
            C_RST_POL    => C_RST_POL,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset,
            din     => north_REG_din,
            din_v   => north_REG_din_v,
            din_r   => north_REG_din_r,
            dout    => north_dout,
            dout_v  => north_dout_v,
            dout_r  => north_dout_r
        );
        
    ------------------------------- NORTH NODE -------------------------------
    
    ------------------------------- EAST  NODE -------------------------------
    -- East node input
    
    FIFO_Ein : entity work.D_FIFO
        Generic map (
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH,
            C_FIFO_DEPTH    => C_FIFO_DEPTH
        )
        port map (
            clk     => clk,
            reset   => reset,
            din     => east_din,
            din_v   => east_din_v,
            din_r   => east_din_r,
            dout    => east_buffer,
            dout_v  => east_buffer_v,
            dout_r  => east_buffer_r
        );
        
    FS_Ein : entity work.fork_sender
        generic map (
            C_NUMBER_OF_READYS => 5
        )
        port map(
            ready_in        => east_buffer_r,
            ready_out(0)    => west_REG_din_r,
            ready_out(1)    => south_REG_din_r,
            ready_out(2)    => north_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            fork_mask       => accept_mask_fsiE
        );  

    -- East node output
    
    MUX_Eout : entity work.conf_mux 
        generic map(
            C_NUM_INPUTS => 4,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            selector    => mux_E_sel,
            mux_input   => west_buffer & south_buffer & north_buffer & FU_dout, 
            mux_output  => east_REG_din
        );
        
    FR_Eout : entity work.fork_receiver                                  
        generic map (
            C_NUMBER_OF_VALIDS => 4,
            C_NUMBER_OF_READYS => 5
        )
        port map ( 
            ready_out(0)    => west_REG_din_r,
            ready_out(1)    => south_REG_din_r,
            ready_out(2)    => north_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            valid_in(0)     => FU_dout_v,
            valid_in(1)     => north_buffer_v,
            valid_in(2)     => south_buffer_v,
            valid_in(3)     => west_buffer_v,
            valid_out       => east_REG_din_v,
            valid_mux_sel   => mux_E_sel,
            fork_mask       => accept_mask_frE
        );        
        
    REG_Eout : entity work.D_REG
        generic map(
            C_RST_POL    => C_RST_POL,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset,
            din     => east_REG_din,
            din_v   => east_REG_din_v,
            din_r   => east_REG_din_r,
            dout    => east_dout,
            dout_v  => east_dout_v,
            dout_r  => east_dout_r
        );
        
    ------------------------------- EAST  NODE -------------------------------
    
    ------------------------------- SOUTH NODE -------------------------------
    -- South node input
    
    FIFO_Sin : entity work.D_FIFO
        Generic map (
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH,
            C_FIFO_DEPTH    => C_FIFO_DEPTH
        )
        port map (
            clk     => clk,
            reset   => reset,
            din     => south_din,
            din_v   => south_din_v,
            din_r   => south_din_r,
            dout    => south_buffer,
            dout_v  => south_buffer_v,
            dout_r  => south_buffer_r
        );
        
    FS_Sin : entity work.fork_sender
        generic map (
            C_NUMBER_OF_READYS => 5
        )
        port map(
            ready_in        => south_buffer_r,
            ready_out(0)    => west_REG_din_r,
            ready_out(1)    => east_REG_din_r,
            ready_out(2)    => north_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            fork_mask       => accept_mask_fsiS
        );  

    -- South node output
    
    MUX_Sout : entity work.conf_mux 
        generic map(
            C_NUM_INPUTS => 4,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            selector    => mux_S_sel,
            mux_input   => west_buffer & east_buffer & north_buffer & FU_dout, 
            mux_output  => south_REG_din
        );
        
    FR_Sout : entity work.fork_receiver                                  
        generic map (
            C_NUMBER_OF_VALIDS => 4,
            C_NUMBER_OF_READYS => 5
        )
        port map ( 
            ready_out(0)    => west_REG_din_r,
            ready_out(1)    => east_REG_din_r,
            ready_out(2)    => north_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            valid_in(0)     => FU_dout_v,
            valid_in(1)     => north_buffer_v,
            valid_in(2)     => east_buffer_v,
            valid_in(3)     => west_buffer_v,
            valid_out       => south_REG_din_v,
            valid_mux_sel   => mux_S_sel,
            fork_mask       => accept_mask_frS
        );        
        
    REG_Sout : entity work.D_REG
        generic map(
            C_RST_POL    => C_RST_POL,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset,
            din     => south_REG_din,
            din_v   => south_REG_din_v,
            din_r   => south_REG_din_r,
            dout    => south_dout,
            dout_v  => south_dout_v,
            dout_r  => south_dout_r
        );
        
    ------------------------------- SOUTH NODE -------------------------------
    
    ------------------------------- WEST  NODE -------------------------------
    -- West node input
    
    FIFO_Win : entity work.D_FIFO
        Generic map (
            C_RST_POL       => C_RST_POL,
            C_DATA_WIDTH    => C_DATA_WIDTH,
            C_FIFO_DEPTH    => C_FIFO_DEPTH
        )
        port map (
            clk     => clk,
            reset   => reset,
            din     => west_din,
            din_v   => west_din_v,
            din_r   => west_din_r,
            dout    => west_buffer,
            dout_v  => west_buffer_v,
            dout_r  => west_buffer_r
        );
        
    FS_Win : entity work.fork_sender
        generic map (
            C_NUMBER_OF_READYS => 5
        )
        port map(
            ready_in        => west_buffer_r,
            ready_out(0)    => south_REG_din_r,
            ready_out(1)    => east_REG_din_r,
            ready_out(2)    => north_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            fork_mask       => accept_mask_fsiW
        );  

    -- West node output
    
    MUX_Wout : entity work.conf_mux 
        generic map(
            C_NUM_INPUTS => 4,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            selector    => mux_W_sel,
            mux_input   => south_buffer & east_buffer & north_buffer & FU_dout, 
            mux_output  => west_REG_din
        );
        
    FR_Wout : entity work.fork_receiver                                  
        generic map (
            C_NUMBER_OF_VALIDS => 4,
            C_NUMBER_OF_READYS => 5
        )
        port map ( 
            ready_out(0)    => south_REG_din_r,
            ready_out(1)    => east_REG_din_r,
            ready_out(2)    => north_REG_din_r,
            ready_out(3)    => FU_din_2_r,
            ready_out(4)    => FU_din_1_r,
            valid_in(0)     => FU_dout_v,
            valid_in(1)     => north_buffer_v,
            valid_in(2)     => east_buffer_v,
            valid_in(3)     => south_buffer_v,
            valid_out       => west_REG_din_v,
            valid_mux_sel   => mux_W_sel,
            fork_mask       => accept_mask_frW
        );        
        
    REG_Wout : entity work.D_REG
        generic map(
            C_RST_POL    => C_RST_POL,
            C_DATA_WIDTH => C_DATA_WIDTH
        )
        port map(
            clk     => clk,
            reset   => reset,
            din     => west_REG_din,
            din_v   => west_REG_din_v,
            din_r   => west_REG_din_r,
            dout    => west_dout,
            dout_v  => west_dout_v,
            dout_r  => west_dout_r
        );
        
    ------------------------------- EAST  NODE -------------------------------
    
    -- Cell processing
    CELL : entity work.cell_processing
        generic map(
            C_RST_POL           => C_RST_POL,
            C_DATA_WIDTH        => C_DATA_WIDTH,
            C_FIXED_POINT       => C_FIXED_POINT,
            C_FRACTION_LENGTH   => C_FRACTION_LENGTH
        )
        port map(
            clk     => clk,
            reset   => reset,
            
            -- Data in
            north_din       => north_buffer,
            north_din_v     => north_buffer_v,
            east_din        => east_buffer,
            east_din_v      => east_buffer_v,
            south_din       => south_buffer,
            south_din_v     => south_buffer_v,
            west_din        => west_buffer,
            west_din_v      => west_buffer_v,
            FU_din_1_r      => FU_din_1_r,
            FU_din_2_r      => FU_din_2_r,
            dout            => FU_dout,
            dout_v          => FU_dout_v,
            north_dout_r    => north_REG_din_r,
            east_dout_r     => east_REG_din_r,
            south_dout_r    => south_REG_din_r,
            west_dout_r     => west_REG_din_r,
            config_bits     => config_bits_reg
        );

end Behavioral;