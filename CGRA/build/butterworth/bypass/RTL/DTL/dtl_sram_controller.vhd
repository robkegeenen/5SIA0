LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_arith.ALL;

ENTITY dtl_sram_controller IS
    GENERIC (
        addr_width : natural     := 18;
        data_width : natural     := 32;
        block_size_bits: natural := 5;
        C_LMB_AWIDTH : integer := 32;
        C_LMB_DWIDTH : integer := 32;
        C_BASEADDR : std_logic_vector(31 DOWNTO 0) := (others => '1');
        C_HIGHADDR : std_logic_vector(31 DOWNTO 0) := (others => '0')
    );
    PORT (
        clk                : IN  std_logic;
        rst                : IN  std_logic;
        dtl_cmd_valid      : IN  std_logic;
        dtl_cmd_accept     : OUT std_logic;
        dtl_cmd_addr       : IN  std_logic_vector(31 DOWNTO 0);
        dtl_cmd_read       : IN  std_logic;
        dtl_cmd_block_size : IN  std_logic_vector(block_size_bits-1 DOWNTO 0);

        dtl_wr_valid       : IN  std_logic;
        dtl_wr_last        : IN  std_logic;
        dtl_wr_accept      : OUT std_logic;
        dtl_wr_mask        : IN  std_logic_vector(3 downto 0);
        dtl_wr_data        : IN  std_logic_vector(data_width-1 DOWNTO 0);

        dtl_rd_valid       : OUT std_logic;
        dtl_rd_last        : OUT std_logic;
        dtl_rd_accept      : IN  std_logic;
        dtl_rd_data        : OUT std_logic_vector(data_width-1 DOWNTO 0);


        ram_clk            : OUT std_logic;
        ram_rst            : out std_logic;
        ram_addr           : OUT std_logic_vector(31 DOWNTO 0);
        ram_wr_data        : OUT std_logic_vector(data_width-1 DOWNTO 0);
        ram_en             : OUT std_logic;
        ram_wbe            : OUT std_logic_vector(3 downto 0);
        ram_rd_data        : IN  std_logic_vector(data_width-1 DOWNTO 0);

        LMB_Clk            : IN  std_logic;
    	LMB_Rst            : IN  std_logic;
        LMB_ABus           : IN  std_logic_vector(0 to C_LMB_AWIDTH-1);
        LMB_WriteDBus      : IN  std_logic_vector(0 to C_LMB_DWIDTH-1);
        LMB_AddrStrobe     : IN  std_logic;
        LMB_ReadStrobe     : IN  std_logic;
        LMB_WriteStrobe    : IN  std_logic;
        LMB_BE             : IN  std_logic_vector(0 to C_LMB_DWIDTH/8-1);
        SL_DBus            : OUT std_logic_vector(0 to C_LMB_DWIDTH-1);
        SL_Ready           : OUT std_logic;
        SL_Wait            : OUT std_logic;
        SL_UE              : OUT std_logic;
        SL_CE              : OUT std_logic
    );
END dtl_sram_controller;

ARCHITECTURE rtl OF dtl_sram_controller IS
    subtype ADDR_RNG is natural range addr_width-1 downto 0;
    subtype ADDR_T   is std_logic_vector(addr_width-1 downto 0);
    subtype BLK_SIZE_T is std_logic_vector(block_size_bits-1 downto 0);

    type STATE_T is (ST_IDLE, ST_READ, ST_WRITE);
    signal state_r,state_nxt : STATE_T;

    signal addr_r   : ADDR_T := (others => '0');
    signal addr_nxt : ADDR_T;
    signal size_r   : BLK_SIZE_T := (others => '0');
    signal size_nxt : BLK_SIZE_T;

    signal dtl_rd_valid_r, dtl_rd_valid_nxt : std_logic;
    signal dtl_rd_last_r,  dtl_rd_last_nxt  : std_logic;

    signal dtl_wr_accept_r, dtl_wr_accept_nxt : std_logic;
BEGIN

    ram_clk     <= clk;
    ram_rst     <= rst;
    ram_en      <= '1';
    dtl_rd_data <= ram_rd_data;
    ram_wr_data <= dtl_wr_data;
    ram_addr(31 downto addr_width) <= (others => '0');

    dtl_rd_valid <= dtl_rd_valid_r;
    dtl_rd_last  <= dtl_rd_last_r;
    dtl_wr_accept <= dtl_wr_accept_r;

    state: PROCESS (clk)
    BEGIN
        IF RISING_EDGE(clk) THEN
            dtl_rd_last_r <= dtl_rd_last_nxt;
            addr_r <= addr_nxt;
            size_r <= size_nxt;
            IF (rst = '1') THEN
                state_r <= ST_IDLE;
                dtl_rd_valid_r  <= '0';
                dtl_wr_accept_r <= '0';
		dtl_rd_last_r <= '0';

            ELSE
                state_r <= state_nxt;
                dtl_rd_valid_r  <= dtl_rd_valid_nxt;
                dtl_wr_accept_r <= dtl_wr_accept_nxt;
            END IF;
        END IF;
    END PROCESS state;

    main: process(state_r,
                  dtl_cmd_valid,
                  dtl_cmd_read,
                  dtl_cmd_addr,
                  dtl_cmd_block_size,
                  dtl_wr_valid,
                  dtl_wr_data,
                  dtl_wr_mask,
                  dtl_wr_accept_r,
                  dtl_rd_accept,
                  dtl_rd_valid_r,
                  dtl_rd_last_r,
                  addr_r,
                  size_r
                  )
        variable var_state             : STATE_T;
        variable var_dtl_cmd_accept    : std_logic;
        variable var_dtl_wr_accept_nxt : std_logic;
        variable var_addr_nxt          : ADDR_T;
        variable var_ram_addr          : ADDR_T;
        variable var_WEB               : std_logic_vector(data_width/8 -1 downto 0);
        variable var_size              : BLK_SIZE_T;
        variable var_dtl_rd_valid_nxt  : std_logic;
        variable var_dtl_rd_last_nxt   : std_logic;
    begin
        var_state := state_r;
        var_size  := size_r;

        var_dtl_cmd_accept :='0';
        var_dtl_wr_accept_nxt  := dtl_wr_accept_r;
        var_addr_nxt       := addr_r;
        var_ram_addr       := addr_r;
        var_WEB            := (others => '0');

        var_dtl_rd_valid_nxt := dtl_rd_valid_r;
        var_dtl_rd_last_nxt  := dtl_rd_last_r;

        case var_state is
            when ST_IDLE =>
                var_dtl_cmd_accept:='1';
                var_addr_nxt := dtl_cmd_addr(addr_width-1 downto 0);
                var_ram_addr := dtl_cmd_addr(addr_width-1 downto 0);
                var_size     := dtl_cmd_block_size;
                IF dtl_cmd_valid='1' THEN
                    IF dtl_cmd_read = '1' THEN  -- read action
                        var_state := ST_READ;
                        var_dtl_rd_valid_nxt := '1';
                        if unsigned(dtl_cmd_block_size) = 0 then
                            var_dtl_rd_last_nxt := '1';
                        else
                            var_dtl_rd_last_nxt := '0';
                        end if;
                    ELSE                      -- write action
                        var_state := ST_WRITE;
                        var_dtl_wr_accept_nxt := '1';
                    END IF;
                END IF;

            when ST_WRITE =>                 -- Write action
                IF dtl_wr_valid='1' THEN -- handle the write
                    var_WEB := dtl_wr_mask;
                    IF unsigned(size_r) = 0 THEN
                        var_state := ST_IDLE;
                        var_dtl_wr_accept_nxt := '0';
                    END IF;
                    var_size     := unsigned(size_r)-1;
                    var_addr_nxt := unsigned(addr_r)+4;
                END IF;

            when ST_READ =>                -- Read action
                if dtl_rd_accept='1' then -- handle the read
                    if dtl_rd_last_r = '1' then
                        var_dtl_cmd_accept:='1';
                        var_addr_nxt := dtl_cmd_addr(addr_width-1 downto 0);
                        var_ram_addr := dtl_cmd_addr(addr_width-1 downto 0);
                        var_size     := dtl_cmd_block_size;
                        if dtl_cmd_valid ='1' then -- There is a next action
                            if dtl_cmd_read = '1' then  -- read action
                                -- Remain in the read state, so rd_valid remains high.
                                if unsigned(dtl_cmd_block_size) = 0 then
                                    var_dtl_rd_last_nxt := '1';
                                else
                                    var_dtl_rd_last_nxt := '0';
                                end if;
                            else            -- write action
                                var_state := ST_WRITE;
                                var_dtl_rd_valid_nxt  := '0';
                                var_dtl_wr_accept_nxt := '1';
                            end if;
                        else
                            var_state := ST_IDLE;
                            var_dtl_rd_valid_nxt := '0';
                        end if;
                    else
                        -- Go to next word
                        if unsigned(size_r) = 1 then
                            var_dtl_rd_last_nxt := '1';
                        else
                            var_dtl_rd_last_nxt := '0';
                        end if;
                        var_size     := unsigned(size_r)-1;
                        var_addr_nxt := unsigned(addr_r)+4;
                        var_ram_addr := var_addr_nxt;
                    end if;

                end if;
            when others => null;
        end case;

        dtl_rd_last_nxt   <= var_dtl_rd_last_nxt;
        dtl_rd_valid_nxt  <= var_dtl_rd_valid_nxt;
        dtl_wr_accept_nxt <= var_dtl_wr_accept_nxt;
        dtl_cmd_accept <= var_dtl_cmd_accept;
        state_nxt      <= var_state;
        size_nxt       <= var_size;
        addr_nxt       <= var_addr_nxt;
        ram_addr(addr_width-1 downto 0) <= var_ram_addr;
        ram_wbe        <= var_WEB;
    end process main;

    Sl_DBus           <= (others => '0');
    Sl_Ready          <= '0';
    Sl_Wait           <= '0';
    Sl_UE             <= '0';
    Sl_CE             <= '0';
end rtl;
