//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable,

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,

///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,

output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
//
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig

);

//Analogizer settings
localparam [7:0] ADDRESS_ANALOGIZER_CONFIG = 8'hF7;

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart pins are driven by the Analogizer block at the bottom of this file.
// When its enable is low it restores exactly what this core asserted before
// Analogizer landed: bank0 = 4'hf/out, banks 1-3 = 8'hzz/in, pin30/31 = z.
// directions are 0:IN, 1:OUT
// assign cart_tran_bank3 = 8'hzz;
// assign cart_tran_bank3_dir = 1'b0;
// assign cart_tran_bank2 = 8'hzz;
// assign cart_tran_bank2_dir = 1'b0;
// assign cart_tran_bank1 = 8'hzz;
// assign cart_tran_bank1_dir = 1'b0;
// assign cart_tran_bank0 = 4'hf;
// assign cart_tran_bank0_dir = 1'b1;
// assign cart_tran_pin30 = 1'b0;      // reset or cs2, we let the hw control it by itself
// assign cart_tran_pin30_dir = 1'bz;
// assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
// assign cart_tran_pin31 = 1'bz;      // input
// assign cart_tran_pin31_dir = 1'b0;  // input

// link port is unused, set to input only to be safe
// each bit may be bidirectional in some applications
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

assign dram_a = 'h0;
assign dram_ba = 'h0;
assign dram_dq = {16{1'bZ}};
assign dram_dqm = 'h0;
assign dram_clk = 'h0;
assign dram_cke = 'h0;
assign dram_ras_n = 'h1;
assign dram_cas_n = 'h1;
assign dram_we_n = 'h1;

assign sram_a = 'h0;
assign sram_dq = {16{1'bZ}};
assign sram_oe_n  = 1;
assign sram_we_n  = 1;
assign sram_ub_n  = 1;
assign sram_lb_n  = 1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;


// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
wire [31:0] analogizer_bridge_rd_data;

// the high-score save slot, declared up here because the read mux below
// reaches for it. Driven further down, with the game side of the core.
    reg  [63:0] hs_file = {64{1'b1}};

// bus-communication.md: "Upon receiving a read the core may not immediately
// provide the read data and has up until the next read strobe to drive
// bridge_rd_data." So the framework samples the answer to a read when the NEXT
// read arrives, by which time bridge_addr has moved on. A mux driven straight
// off bridge_addr answers with the following word instead, which for a two
// word slot swaps its halves -- and answers the last word with whatever came
// after the slot, which is why an untouched save first read back as
// FF FF FF FF 00 00 00 00. Latch the address each strobe arrives with and
// answer from that.
//
// Only this slot is served from the latched address. The framework region has
// its own handling inside core_bridge_cmd and the rest of the mux returns
// values that do not depend on which address asked, so they are left alone.
    reg  [31:0] hs_rd_addr = 32'h0;
always @(posedge clk_74a) if (bridge_rd) hs_rd_addr <= bridge_addr;

    wire hs_rd_hit = (hs_rd_addr[31:4] == 28'h3000000);
    wire [31:0] hs_rd_data = hs_rd_addr[2]
        ? { hs_file[39:32], hs_file[47:40], hs_file[55:48], hs_file[63:56] }
        : { hs_file[ 7: 0], hs_file[15: 8], hs_file[23:16], hs_file[31:24] };

always @(*) begin
    if (hs_rd_hit) bridge_rd_data <= hs_rd_data;
    else
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'h10000000: begin
        bridge_rd_data <= {24'h0, dsw_reg};
    end
    32'h10xxxxxx: begin
        // example
        // bridge_rd_data <= example_device_data;
        bridge_rd_data <= 0;
    end
    // High-score save slot. bridge_endian_little is 0, so the first byte of
    // the file is the top byte of the word -- the same swap data_loader does
    // on the way in. Byte 0 is $8060.
    {ADDRESS_ANALOGIZER_CONFIG,24'h0}: begin
        bridge_rd_data <= analogizer_bridge_rd_data;
    end // Analogizer
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;

// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked_s;
    wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;

    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;

    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

    reg             target_dataslot_read;
    reg             target_dataslot_write;
    reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped

    wire            target_dataslot_ack;
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;

    wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands

// bridge data slot access
// synchronous to clk_74a

    reg     [9:0]   datatable_addr = 10'd0;
    reg             datatable_wren = 1'b0;
    reg     [31:0]  datatable_data = 32'd0;
    wire    [31:0]  datatable_q;

// APF sizes a nonvolatile slot from the file it loaded, so on a first run --
// when no save file exists yet -- it would read nothing back out unless the
// core states the size itself. The high-score slot is eight bytes and sits at
// slot index 2, whose size word the table addresses as index*2 + 1.
always @(posedge clk_74a) begin
    datatable_wren <= 1'b1;
    datatable_addr <= 10'd5;
    datatable_data <= 32'd8;
end

core_bridge_cmd icb (

    .clk                ( clk_74a ),
    .reset_n            ( reset_n ),

    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_rd              ( bridge_rd ),
    .bridge_rd_data         ( cmd_bridge_rd_data ),
    .bridge_wr              ( bridge_wr ),
    .bridge_wr_data         ( bridge_wr_data ),

    .status_boot_done       ( status_boot_done ),
    .status_setup_done      ( status_setup_done ),
    .status_running         ( status_running ),

    .dataslot_requestread       ( dataslot_requestread ),
    .dataslot_requestread_id    ( dataslot_requestread_id ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok ),

    .dataslot_requestwrite      ( dataslot_requestwrite ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
    .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

    .dataslot_update            ( dataslot_update ),
    .dataslot_update_id         ( dataslot_update_id ),
    .dataslot_update_size       ( dataslot_update_size ),

    .dataslot_allcomplete   ( dataslot_allcomplete ),

    .rtc_epoch_seconds      ( rtc_epoch_seconds ),
    .rtc_date_bcd           ( rtc_date_bcd ),
    .rtc_time_bcd           ( rtc_time_bcd ),
    .rtc_valid              ( rtc_valid ),

    .savestate_supported    ( savestate_supported ),
    .savestate_addr         ( savestate_addr ),
    .savestate_size         ( savestate_size ),
    .savestate_maxloadsize  ( savestate_maxloadsize ),

    .savestate_start        ( savestate_start ),
    .savestate_start_ack    ( savestate_start_ack ),
    .savestate_start_busy   ( savestate_start_busy ),
    .savestate_start_ok     ( savestate_start_ok ),
    .savestate_start_err    ( savestate_start_err ),

    .savestate_load         ( savestate_load ),
    .savestate_load_ack     ( savestate_load_ack ),
    .savestate_load_busy    ( savestate_load_busy ),
    .savestate_load_ok      ( savestate_load_ok ),
    .savestate_load_err     ( savestate_load_err ),

    .osnotify_inmenu        ( osnotify_inmenu ),

    .target_dataslot_read       ( target_dataslot_read ),
    .target_dataslot_write      ( target_dataslot_write ),
    .target_dataslot_getfile    ( target_dataslot_getfile ),
    .target_dataslot_openfile   ( target_dataslot_openfile ),

    .target_dataslot_ack        ( target_dataslot_ack ),
    .target_dataslot_done       ( target_dataslot_done ),
    .target_dataslot_err        ( target_dataslot_err ),

    .target_dataslot_id         ( target_dataslot_id ),
    .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
    .target_dataslot_length     ( target_dataslot_length ),

    .target_buffer_param_struct ( target_buffer_param_struct ),
    .target_buffer_resp_struct  ( target_buffer_resp_struct ),

    .datatable_addr         ( datatable_addr ),
    .datatable_wren         ( datatable_wren ),
    .datatable_data         ( datatable_data ),
    .datatable_q            ( datatable_q )

);



////////////////////////////////////////////////////////////////////////////////////////
// Rally-X game core + ROM loader + controls
////////////////////////////////////////////////////////////////////////////////////////

// ---- ROM download: bridge writes -> data_loader -> game ROM download port ----
// data_loader (agg23, MIT) buffers APF bridge writes across the clock domain and
// emits a byte-wise write stream. Rally-X ROMs are a single ~21KB blob loaded at
// bridge address 0x00000000; see PORT_PLAN.md for the byte layout.
    wire        ioctl_wr;
    wire [24:0] ioctl_addr;
    wire  [7:0] ioctl_dout;

data_loader #(
    .ADDRESS_MASK_UPPER_4 ( 4'h0 ),
    .ADDRESS_SIZE         ( 25 ),
    .OUTPUT_WORD_SIZE     ( 1 )
) rom_loader (
    .clk_74a              ( clk_74a ),
    .clk_memory           ( clk_core_24576 ),

    .bridge_wr            ( bridge_wr ),
    .bridge_endian_little ( bridge_endian_little ),
    .bridge_addr          ( bridge_addr ),
    .bridge_wr_data       ( bridge_wr_data ),

    .write_en             ( ioctl_wr ),
    .write_addr           ( ioctl_addr ),
    .write_data           ( ioctl_dout )
);

// ---- hold the game in reset while the game ROM loads ----
// tracked in the clk_74a (bridge) domain, then synchronized into the game clock.
//
// The game ROM is slot 0, and it is the only slot that decides whether the game
// may run. APF sends [0082] Data slot request write long after boot too: the
// high-score slot is nonvolatile, so saving a score brings one with it. Gating
// on every slot meant a save reset the running game, and the reset re-armed the
// save and reset it again -- issue #8, a black screen and the power-on
// self-test flickering forever. Reloading slot 0 to switch games must still
// reset, so this watches the slot id rather than watching for the first boot.
// Every other slot loads underneath a game that keeps running.
    localparam [15:0] ROM_SLOT_ID = 16'd0;

    reg  download_done = 1'b0;
always @(posedge clk_74a) begin
    if (dataslot_requestwrite && dataslot_requestwrite_id == ROM_SLOT_ID)
        download_done <= 1'b0;
    else if (dataslot_allcomplete)
        download_done <= 1'b1;
end

    wire download_done_s;
    wire reset_n_s;
synch_3 s_dl (download_done, download_done_s, clk_core_24576);
synch_3 s_rn (reset_n,       reset_n_s,       clk_core_24576);
    wire pause_menu_s;
synch_3 s_pa (osnotify_inmenu, pause_menu_s, clk_core_24576);
    wire pause_btn_rise;
synch_3 s_pb (.i(cont1_key[8]), .clk(clk_core_24576), .rise(pause_btn_rise));
    reg pause_toggle = 1'b0;
always @(posedge clk_core_24576) if (pause_btn_rise) pause_toggle <= ~pause_toggle;
    // the hiscore block pauses the Z80 around its own RAM accesses, because
    // reaching the score row takes the CPU's port away from it
    wire hs_pause;
    wire pause_s = pause_toggle | pause_menu_s | hs_pause;
    // active-high game reset: held until ROMs are loaded AND host reset released
    wire game_reset = ~reset_n_s | ~download_done_s | dsw_reset;

    reg  [7:0] dsw_coin  = 8'h00;
    reg  [7:0] dsw_diff  = 8'h38;
    reg  [7:0] dsw_bonus = 8'h04;
    reg  [7:0] dsw_serv  = 8'h00;

    reg        ena_analogizer = 0;

always @(posedge clk_74a) begin
    if (bridge_wr && bridge_addr == 32'h10000000) dsw_coin  <= bridge_wr_data[7:0];
    if (bridge_wr && bridge_addr == 32'h10010000) dsw_diff  <= bridge_wr_data[7:0];
    if (bridge_wr && bridge_addr == 32'h10020000) dsw_bonus <= bridge_wr_data[7:0];
    if (bridge_wr && bridge_addr == 32'h10030000) dsw_serv  <= bridge_wr_data[7:0];
    if (bridge_wr && bridge_addr == 32'hf2000000) ena_analogizer <= bridge_wr_data[0];
end

    wire [7:0] dsw_reg = dsw_coin | dsw_diff | dsw_bonus | dsw_serv;
    wire [7:0] dsw_s;
synch_3 #(.WIDTH(8)) s_dsw (dsw_reg, dsw_s, clk_core_24576);
    reg  [7:0]  dsw_s_d  = 8'h3C;
    reg  [15:0] dsw_hold = 16'h0;
always @(posedge clk_core_24576) begin
    dsw_s_d <= dsw_s;
    if (dsw_s != dsw_s_d)          dsw_hold <= 16'hFFFF;
    else if (dsw_hold != 16'h0)    dsw_hold <= dsw_hold - 16'd1;
end
    wire dsw_reset = (dsw_hold != 16'h0);

// ---- high-score save slot ----
// hs_file serves both directions. APF fills it from the save file at boot,
// the game side publishes captures back into it, and APF reads it out again
// when the core shuts down. All ones is what a first run looks like: no file,
// so nothing to restore.
//
// The two writers never overlap. APF loads while the game is still held in
// reset, and the game side cannot capture anything until long after that.
    wire [63:0] hs_capture;
    wire        hs_capture_tgl;
    wire        hs_capture_tgl_s;
    reg         hs_capture_tgl_d = 1'b0;

synch_3 s_hstgl (hs_capture_tgl, hs_capture_tgl_s, clk_74a);

always @(posedge clk_74a) begin
    // hs_capture is stable for a second either side of its toggle, so the
    // toggle is the only thing that needs synchronising.
    hs_capture_tgl_d <= hs_capture_tgl_s;
    if (hs_capture_tgl_s != hs_capture_tgl_d) hs_file <= hs_capture;
end

// The save file arrives the same way the ROM does. Catching bridge writes by
// hand looked simpler, but the address runs a word ahead of the data, so the
// two halves of an eight byte slot land swapped -- which put "7650   8" on the
// panel instead of "   87650". data_loader already does the edge detect, the
// endian swap and the byte addressing, and the ROM slot has been loading
// through it since this core booted for the first time.
    wire       hs_load_wr;
    wire [3:0] hs_load_addr;
    wire [7:0] hs_load_data;

data_loader #(
    .ADDRESS_MASK_UPPER_4 ( 4'h3 ),
    .ADDRESS_SIZE         ( 4 ),
    .OUTPUT_WORD_SIZE     ( 1 )
) hs_loader (
    .clk_74a              ( clk_74a ),
    .clk_memory           ( clk_core_24576 ),

    .bridge_wr            ( bridge_wr ),
    .bridge_endian_little ( bridge_endian_little ),
    .bridge_addr          ( bridge_addr ),
    .bridge_wr_data       ( bridge_wr_data ),

    .write_en             ( hs_load_wr ),
    .write_addr           ( hs_load_addr ),
    .write_data           ( hs_load_data )
);

// Assembled in the core clock domain, so the game side reads it directly with
// no crossing at all. Byte 0 is $8060. A slot write means a different game is
// arriving, so drop the old bytes first: if that game has no save file of its
// own, nothing will overwrite them and the last game's score would be restored
// into it.
    reg [63:0] hs_load = {64{1'b1}};
    reg        download_done_d = 1'b0;
always @(posedge clk_core_24576) begin
    download_done_d <= download_done_s;
    if (download_done_d && !download_done_s)
        hs_load <= {64{1'b1}};
    else if (hs_load_wr && hs_load_addr < 4'd8)
        hs_load[hs_load_addr*8 +: 8] <= hs_load_data;
end

    wire ena_analogizer_s;


synch_3 #(1) analogizer_ena_sync({ena_analogizer}, {ena_analogizer_s}, clk_core_24576);

// ---- controls: cont1_key (active-high) -> CTR1 (active-low) ----
// CTR bit order (MSB..LSB): {coin, start, up, down, right, left, smoke, unused}
//
// p1_controls is registered on clk_74a; the game runs on clk_core_24576, and
// core_constraints.sdc declares those two asynchronous. That false-paths the
// crossing, so Quartus reports nothing and the Z80 can sample a button bit
// mid-transition. Synchronise it here, the way every other host signal in this
// file already does. Both the Pocket pad and the SNAC pad funnel through
// p1_controls, so one synchroniser covers both.
    wire [15:0] p1_controls_s;
synch_3 #(.WIDTH(16)) s_p1 (p1_controls, p1_controls_s, clk_core_24576);

    wire [7:0] ctr1 = ~{ p1_controls_s[14], p1_controls_s[15], p1_controls_s[0],
                         p1_controls_s[1],  p1_controls_s[3],  p1_controls_s[2],
                         p1_controls_s[4],  1'b0 };
    wire [7:0] ctr2 = 8'hFF;   // P2 unused for now (active-low idle)

// ---- high score restore/capture, wired to the game's work RAM port ----
    wire [15:0] hs_address;
    wire  [7:0] hs_data_in;
    wire  [7:0] hs_data_out;
    wire        hs_write;
    wire        hs_access;

NRX_HISCORE hiscore (
    .clk         ( clk_core_24576 ),
    .reset       ( game_reset ),
    .loading     ( ~download_done_s ),
    .core_paused ( pause_toggle | pause_menu_s ),

    .save_in     ( hs_load ),
    .save_out    ( hs_capture ),
    .save_tgl    ( hs_capture_tgl ),

    .hs_address  ( hs_address ),
    .hs_data_in  ( hs_data_in ),
    .hs_data_out ( hs_data_out ),
    .hs_write    ( hs_write ),
    .hs_access   ( hs_access ),
    .pause_cpu   ( hs_pause )
);

// ---- game instance + external HVGEN video-timing generator ----
    wire  [8:0] rx_hpos, rx_vpos;
    wire        rx_pclk;
    wire  [7:0] rx_pout;
    wire  [7:0] rx_snd;
    wire [11:0] rx_orgb;
    wire        rx_hblk, rx_vblk, rx_hsyn, rx_vsyn;

fpga_NRX game (
    .RESET       ( game_reset ),
    .CLK24M      ( clk_core_24576 ),

    .HP          ( rx_hpos ),
    .VP          ( rx_vpos ),
    .PCLK        ( rx_pclk ),
    .POUT        ( rx_pout ),

    .SND         ( rx_snd ),

    .DSW         ( ~dsw_s ),
    .CTR1        ( ctr1 ),
    .CTR2        ( ctr2 ),

    .LAMP        (  ),

    .ROMCL       ( clk_core_24576 ),
    .ROMAD       ( ioctl_addr[15:0] ),
    .ROMDT       ( ioctl_dout ),
    .ROMEN       ( ioctl_wr ),

    .pause       ( pause_s ),

    .hs_address  ( hs_address ),
    .hs_data_in  ( hs_data_in ),
    .hs_data_out ( hs_data_out ),
    .hs_write    ( hs_write ),
    .hs_access   ( hs_access )
);

HVGEN hvgen (
    .HPOS ( rx_hpos ),
    .VPOS ( rx_vpos ),
    .PCLK ( rx_pclk ),
    // POUT is the raw Namco palette PROM byte, BBGGGRRR, driving a resistor
    // DAC on the board. Widen each channel to a nibble by REPLICATING its top
    // bits, not by padding with zeros -- padding never reaches full scale, so
    // white came out (238,238,204) and blue topped out at 80%.
    .iRGB ( { rx_pout[7:6], rx_pout[7:6],       // blue  2 bits -> 4
              rx_pout[5:3], rx_pout[5],         // green 3 bits -> 4
              rx_pout[2:0], rx_pout[2] } ),     // red   3 bits -> 4
    .oRGB ( rx_orgb ),
    .HBLK ( rx_hblk ),
    .VBLK ( rx_vblk ),
    .HSYN ( rx_hsyn ),
    .VSYN ( rx_vsyn )
);


////////////////////////////////////////////////////////////////////////////////////////


// video output to the APF scaler, generated in the 6.144 MHz pixel-clock domain.
// The game (via HVGEN) produces its picture on its own PCLK (= CLK24M/4). Because the
// 6.144 MHz output clock and CLK24M come from the same PLL, that crossing is
// synchronous (constant phase) and timed by STA, so a single resample register is safe.

assign video_rgb_clock = clk_core_6144;
assign video_rgb_clock_90 = clk_core_6144_90deg;
assign video_rgb = video_rgb_rallyx; //When Analogizer adapter and pocket_blank_screen are enabled 
                                     //Blank video signal is send to the Pocket Screen
assign video_de = vidout_de;
assign video_skip = vidout_skip;
assign video_vs = vidout_vs;
assign video_hs = vidout_hs;

    // Active window is defined from HVGEN's position counters for a pixel-exact
    // 288x224 raster. HVGEN registers its pixel output (oRGB lags HPOS by one
    // pixel), which without compensation shifts the image right -> margin on the
    // left, clip on the right. H_OFF cancels that lag. Nudge H_OFF/V_OFF by +/-1
    // to fine-tune centering on hardware.
    localparam [8:0] H_ACT = 9'd288;
    localparam [8:0] V_ACT = 9'd224;
    localparam [8:0] H_OFF = 9'd1;
    localparam [8:0] V_OFF = 9'd0;

    reg [23:0]  vidout_rgb;
    reg         vidout_de;
    reg         vidout_skip;
    reg         vidout_vs;
    reg         vidout_hs;

    // resample the game-domain video into the pixel-clock domain
    reg [11:0]  g_rgb;
    reg  [8:0]  g_hpos, g_vpos;
    reg         g_hsyn, g_vsyn, g_hsyn_d, g_vsyn_d;

    wire h_active = (g_hpos >= H_OFF) && (g_hpos < H_OFF + H_ACT);
    wire v_active = (g_vpos >= V_OFF) && (g_vpos < V_OFF + V_ACT);

always @(posedge clk_core_6144) begin
    g_rgb    <= rx_orgb;
    g_hpos   <= rx_hpos;
    g_vpos   <= rx_vpos;
    g_hsyn   <= rx_hsyn;
    g_vsyn   <= rx_vsyn;
    g_hsyn_d <= g_hsyn;
    g_vsyn_d <= g_vsyn;

    vidout_skip <= 1'b0;

    // data enable + pixel, gated by the exact active window.
    // oRGB is {blue,green,red} 4-bit nibbles -> RGB888 by nibble replication.
    if (h_active && v_active) begin
        vidout_de  <= 1'b1;
        vidout_rgb <= { {2{g_rgb[3:0]}}, {2{g_rgb[7:4]}}, {2{g_rgb[11:8]}} };
    end else begin
        vidout_de  <= 1'b0;
        vidout_rgb <= 24'h0;
    end

    // single-cycle sync pulses on the falling edge of the active-low HVGEN syncs
    vidout_hs <= g_hsyn_d & ~g_hsyn;
    vidout_vs <= g_vsyn_d & ~g_vsyn;
end




//
// audio: Namco WSG output (SND, 8-bit unsigned, small 0..108 magnitude) -> APF I2S.
// Force the sign bit to 0 (unsigned) and left-justify by 7 bits (x128) so the
// small magnitude fills the 16-bit field and is audible; mono L = R. pocket_i2s
// (opengateware, APF stock example) re-samples continuously via synch_3 each
// 48 kHz frame off clk_74a -- no change-detect FIFO. Mirrors the working Dig Dug
// core (same Namco WSG sound hardware).
//
    // Cross the WSG sound from the game clock into the audio (clk_74a) domain.
    // SND updates at ~96 kHz in clk_core_24576; feeding it straight to pocket_i2s
    // (which samples the bus asynchronously) caught it mid-transition and folded
    // into a fixed alias tone. Instead: sample-and-hold at 48 kHz in the game
    // domain with a toggle flag, then latch the (stable) value into clk_74a on the
    // synchronized flag edge -- a coherent handshake, no incoherent bus samples.
    reg  [8:0] snd_div  = 9'd0;     // 24.576 MHz / 512 = 48 kHz
    reg  [7:0] snd_hold = 8'd0;
    reg        snd_flag = 1'b0;
always @(posedge clk_core_24576) begin
    snd_div <= snd_div + 1'b1;
    if (snd_div == 9'd0) begin
        snd_hold <= rx_snd;
        snd_flag <= ~snd_flag;
    end
end

    wire       snd_flag_s, snd_flag_rise, snd_flag_fall;
    reg  [7:0] snd_audio = 8'd0;
synch_3 s_snd (snd_flag, snd_flag_s, clk_74a, snd_flag_rise, snd_flag_fall);
always @(posedge clk_74a)
    if (snd_flag_rise || snd_flag_fall)
        snd_audio <= snd_hold;

    // unsigned WSG magnitude, left-justified x128, sign bit 0, mono L=R
    wire [15:0] audio_lr = { 1'b0, snd_audio, 7'h0 };

pocket_i2s audio_i2s (
    .iCLK_74  ( clk_74a ),
    .AUDIO_L  ( audio_lr ),
    .AUDIO_R  ( audio_lr ),
    .I2S_MCLK ( audio_mclk ),
    .I2S_DAC  ( audio_dac ),
    .I2S_LRCK ( audio_lrck )
);


///////////////////////////////////////////////


    wire    clk_core_12288;
    wire    clk_core_12288_90deg;
    wire    clk_core_24576;         // Rally-X master clock (CLK24M)
    wire    clk_core_6144;          // pixel clock 0deg   -> video_rgb_clock
    wire    clk_core_6144_90deg;    // pixel clock 90deg  -> video_rgb_clock_90

    wire    pll_core_locked;
    wire    pll_core_locked_s;
synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

mf_pllbase mp1 (
    .refclk         ( clk_74a ),
    .rst            ( 0 ),

    .outclk_0       ( clk_core_12288 ),
    .outclk_1       ( clk_core_12288_90deg ),
    .outclk_2       ( clk_core_24576 ),
    .outclk_3       ( clk_core_6144 ),
    .outclk_4       ( clk_core_6144_90deg ),

    .locked         ( pll_core_locked )
);

/*[ANALOGIZER_HOOK_BEGIN]*/
    //reg analogizer_ena;
    wire [3:0] analogizer_video_type;
    wire [4:0] snac_game_cont_type;
    wire [3:0] snac_cont_assignment;
    wire       pocket_blank_screen;

    wire analogizer_ena = ena_analogizer_s; //Setting from Pocket Menu 'Enable Analogizer'

    //create aditional switch to blank Pocket screen.
    wire [23:0] video_rgb_rallyx;
    assign video_rgb_rallyx = (pocket_blank_screen && analogizer_ena) ? 24'h000000: vidout_rgb;


    //switch between Analogizer SNAC and Pocket Controls for P1-P4 (P3,P4 when uses PCEngine Multitap)
    wire [15:0] p1_btn; 
    //wire [15:0] p2_btn; 
    //wire [15:0] p3_btn; 
    //wire [15:0] p4_btn;
    wire [31:0] p1_joy; 
    //wire [31:0] p2_joy;
    reg [31:0] p1_joystick;
    //reg [31:0] p2_joystick;
    reg  [15:0] p1_controls;
    //reg  [15:0] p2_controls;

    wire snac_is_analog = (snac_game_cont_type == 5'h12) || (snac_game_cont_type == 5'h13);

    //! Player 1 ---------------------------------------------------------------------------
    reg p1_up, p1_down, p1_left, p1_right;
    wire p1_up_analog, p1_down_analog, p1_left_analog, p1_right_analog;
    //using left analog joypad
    assign p1_up_analog    = (p1_joy[15:8] < 8'h40) ? 1'b1 : 1'b0; //analog range UP 0x00 Idle 0x7F DOWN 0xFF, DEADZONE +- 0x15
    assign p1_down_analog  = (p1_joy[15:8] > 8'hC0) ? 1'b1 : 1'b0; 
    assign p1_left_analog  = (p1_joy[7:0]  < 8'h40) ? 1'b1 : 1'b0; //analog range LEFT 0x00 Idle 0x7F RIGHT 0xFF, DEADZONE +- 0x15
    assign p1_right_analog = (p1_joy[7:0]  > 8'hC0) ? 1'b1 : 1'b0;

    always @(posedge clk_74a) begin
        p1_up    <= (snac_is_analog) ? p1_up_analog    : p1_btn[0];
        p1_down  <= (snac_is_analog) ? p1_down_analog  : p1_btn[1];
        p1_left  <= (snac_is_analog) ? p1_left_analog  : p1_btn[2];
        p1_right <= (snac_is_analog) ? p1_right_analog : p1_btn[3];
    end
    //! Player 2 ---------------------------------------------------------------------------
    // reg p2_up, p2_down, p2_left, p2_right;
    // wire p2_up_analog, p2_down_analog, p2_left_analog, p2_right_analog;
    // //using left analog joypad
    // assign p2_up_analog    = (p2_joy[15:8] < 8'h40) ? 1'b1 : 1'b0; //analog range UP 0x00 Idle 0x7F DOWN 0xFF, DEADZONE +- 0x15
    // assign p2_down_analog  = (p2_joy[15:8] > 8'hC0) ? 1'b1 : 1'b0; 
    // assign p2_left_analog  = (p2_joy[7:0]  < 8'h40) ? 1'b1 : 1'b0; //analog range LEFT 0x00 Idle 0x7F RIGHT 0xFF, DEADZONE +- 0x15
    // assign p2_right_analog = (p2_joy[7:0]  > 8'hC0) ? 1'b1 : 1'b0;

    // always @(posedge clk_74a) begin
    //     p2_up    <= (snac_is_analog) ? p2_up_analog    : p2_btn[0];
    //     p2_down  <= (snac_is_analog) ? p2_down_analog  : p2_btn[1];
    //     p2_left  <= (snac_is_analog) ? p2_left_analog  : p2_btn[2];
    //     p2_right <= (snac_is_analog) ? p2_right_analog : p2_btn[3];
    // end
    always @(posedge clk_74a) begin
        reg [31:0] p1_pocket_btn, p1_pocket_joy;
        //reg [31:0] p2_pocket_btn, p2_pocket_joy;

        if((snac_game_cont_type == 5'h0) || !analogizer_ena) begin //SNAC is disabled
        //if((snac_game_cont_type == 5'h0)) begin //SNAC is disabled
            p1_controls <= cont1_key;
            //p2_controls <= cont2_key;
        end
        else begin
        case(snac_cont_assignment[1:0])
        2'h0:    begin  //SNAC P1 -> Pocket P1
            p1_controls <= {p1_btn[15:4],p1_right,p1_left,p1_down,p1_up};
            //p2_controls <= cont1_key;
            end
        2'h1: begin  //SNAC P1 -> Pocket P2
            p1_controls <= cont1_key;
            //p2_controls <= p1_btn;
            end
        2'h2: begin //SNAC P1 -> Pocket P1, SNAC P2 -> Pocket P2
            p1_controls <= {p1_btn[15:4],p1_right,p1_left,p1_down,p1_up};
            //p2_controls <= {p2_btn[15:4],p2_right,p2_left,p2_down,p2_up};
            end
        //2'h3: begin //SNAC P1 -> Pocket P2, SNAC P2 -> Pocket P1
            //p1_controls <= {p2_btn[15:4],p2_right,p2_left,p2_down,p2_up};
            //p2_controls <= {p1_btn[15:4],p1_right,p1_left,p1_down,p1_up};
         //   end
        default: begin 
            p1_controls <= cont1_key;
            //p2_controls <= cont2_key;
            end
        endcase
        end
    end


    wire [15:0] p1_btn_CK; 
    //wire [15:0] p2_btn_CK;
    wire [31:0] p1_joy_CK; 
    //wire [31:0] p2_joy_CK;
    
    synch_3 #(
    .WIDTH(16)
    ) p1b_s (
        p1_btn_CK,
        p1_btn,
        clk_74a
    );

//    synch_3 #(
//        .WIDTH(16)
//    ) p2b_s (
//        p2_btn_CK,
//        p2_btn,
//        clk_74a
//    );

    // p3b_s is named for its position in this block, not for a player. It
    // carries p1_joy, player 1's analog stick. Deleting it alongside the P2
    // and P4 synchronisers leaves p1_joy undriven, which reads as zero and
    // jams UP and LEFT on for the analog SNAC controller types. Keep it.
    synch_3 #(
    .WIDTH(32)
    ) p3b_s (
        p1_joy_CK,
        p1_joy,
        clk_74a
    );
        
    // synch_3 #(
    //     .WIDTH(32)
    // ) p4b_s (
    //     p2_joy_CK,
    //     p2_joy,
    //     clk_74a
    // );


    // Video Y/C Encoder settings
    // Follows the Mike Simone Y/C encoder settings:
    // https://github.com/MikeS11/MiSTerFPGA_YC_Encoder
    // SET PAL and NTSC TIMING and pass through status bits. ** YC must be enabled in the qsf file **
    wire [39:0] CHROMA_PHASE_INC;
    wire [26:0] COLORBURST_RANGE;

    wire PALFLAG;

    parameter NTSC_REF = 3.579545;   
    parameter PAL_REF = 4.43361875;

    // Parameters to be modifed
    parameter CLK_VIDEO_NTSC = 24.576000 ; // Must be filled E.g XX.X Hz - CLK_VIDEO
    parameter CLK_VIDEO_PAL  = 24.576000 ; // Must be filled E.g XX.X Hz - CLK_VIDEO

    localparam [39:0] NTSC_PHASE_INC1 = 40'd160146132391; // ((NTSC_REF * 2^40) / CLK_VIDEO_NTSC)
    localparam [39:0] PAL_PHASE_INC1  = 40'd198356745148; // ((PAL_REF * 2^40) / CLK_VIDEO_PAL)
  
	localparam [6:0] COLORBURST_START1 = (3.7 * (CLK_VIDEO_NTSC/NTSC_REF));
	localparam [9:0] COLORBURST_NTSC_END1 = (9 * (CLK_VIDEO_NTSC/NTSC_REF)) + COLORBURST_START1;
	localparam [9:0] COLORBURST_PAL_END1 = (10 * (CLK_VIDEO_PAL/PAL_REF)) + COLORBURST_START1;

    assign PALFLAG = (analogizer_video_type == 4'h4); 

    assign CHROMA_PHASE_INC = PALFLAG ? PAL_PHASE_INC1 : NTSC_PHASE_INC1; 
    assign COLORBURST_RANGE = {COLORBURST_START1, COLORBURST_NTSC_END1, COLORBURST_PAL_END1};

    //24_576_000
    wire busy;

    openFPGA_Pocket_Analogizer #(.MASTER_CLK_FREQ(24_576_000), .LINE_LENGTH(288), .ADDRESS_ANALOGIZER_CONFIG(ADDRESS_ANALOGIZER_CONFIG)) analogizer (
        .clk_74a(clk_74a),
        .i_clk(clk_core_24576 ),
        .i_rst_apf(game_reset), //i_rst_apf is active high
        .i_rst_core(game_reset), //i_rst_core is active high
        .i_ena(analogizer_ena),
        //.i_ena(1'b1),

        //Video interface
        .video_clk(clk_core_24576),
        .R({2{rx_orgb[3:0]}}),
        .G({2{rx_orgb[7:4]}}),
        .B({2{rx_orgb[11:8]}}),
        .Hblank(rx_hblk),
        .Vblank(rx_vblk),
        .Hsync(rx_hsyn), //composite SYNC on HSync.
        .Vsync(rx_vsyn),

        //openFPGA Bridge interface
        .bridge_endian_little(bridge_endian_little),
        .bridge_addr(bridge_addr),
        .bridge_rd(bridge_rd),
        .analogizer_bridge_rd_data(analogizer_bridge_rd_data),
        .bridge_wr(bridge_wr),
        .bridge_wr_data(bridge_wr_data),

        //Analogizer settings
        .snac_game_cont_type_out(snac_game_cont_type),
        .snac_cont_assignment_out(snac_cont_assignment),
        .analogizer_video_type_out(analogizer_video_type),
        .SC_fx_out(),
        .pocket_blank_screen_out(pocket_blank_screen),
        .analogizer_osd_out(),

        //Video Y/C Encoder interface
        .CHROMA_PHASE_INC(CHROMA_PHASE_INC),
        .COLORBURST_RANGE(COLORBURST_RANGE),
        .CHROMA_ADD(0),
        .CHROMA_MUL(0),
        .PALFLAG(PALFLAG),
        //Video SVGA Scandoubler interface
        .ce_pix(rx_pclk),
        .scandoubler(1'b1), //logic for disable/enable the scandoubler
        //SNAC interface
        .p1_btn_state(p1_btn_CK),
        .p1_joy_state(p1_joy_CK),
        // .p2_btn_state(p2_btn_CK),  
        // .p2_joy_state(p2_joy_CK),
        .p2_btn_state(),  
        .p2_joy_state(),
        .p3_btn_state(),
        .p4_btn_state(),  
        .busy(busy),    
        //Pocket Analogizer IO interface to the Pocket cartridge port
        .cart_tran_bank2(cart_tran_bank2),
        .cart_tran_bank2_dir(cart_tran_bank2_dir),
        .cart_tran_bank3(cart_tran_bank3),
        .cart_tran_bank3_dir(cart_tran_bank3_dir),
        .cart_tran_bank1(cart_tran_bank1),
        .cart_tran_bank1_dir(cart_tran_bank1_dir),
        .cart_tran_bank0(cart_tran_bank0),
        .cart_tran_bank0_dir(cart_tran_bank0_dir),
        .cart_tran_pin30(cart_tran_pin30),
        .cart_tran_pin30_dir(cart_tran_pin30_dir),
        .cart_pin30_pwroff_reset(cart_pin30_pwroff_reset),
        .cart_tran_pin31(cart_tran_pin31),
        .cart_tran_pin31_dir(cart_tran_pin31_dir),
        //debug
        .o_stb()
    );
    /*[ANALOGIZER_HOOK_END]*/
endmodule
