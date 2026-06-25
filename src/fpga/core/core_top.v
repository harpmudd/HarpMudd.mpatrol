// =============================================================================
// core_top.v — Moon Patrol (Irem M52) core for Analogue Pocket
//
// Ported from MiSTer Arcade-MoonPatrol. The whole game is the VHDL PACE-
// framework wrapper `target_top` (pace = Z80 main + Irem M52 video, PLUS
// moon_patrol_sound_board = 6803 + 2x YM2149 + MSM5205). core_top instantiates
// it intact and re-wraps only the MiSTer sys/ layer with the APF.
//
// Kept verbatim from the HarpMudd skeleton (load-bearing patterns):
//   - APF port list (fixed by framework)         - core_bridge_cmd instance
//   - data_loader (dcfifo CDC; never plain bridge writes)
//   - rom_loaded := dataslot_allcomplete         - reset gating w/ settle ctr
//
// Clock plan (regenerate mf_pllbase, 74.25 ref, 4 outputs):
//   clk_sys 30 MHz -> clock_30 | clk_vid 6 MHz -> clock_v + Pocket pixel
//   clk_vid_90 6 MHz @90° -> DDR | clk_snd 3.582089 MHz -> clock_3p58
//
// ROM image (0xC000 = 49152 B flat, APF data slot 0; MD5 matches MiSTer .mra):
//   0x0000-0x3FFF  Z80 main program   (mpa-1/2/3/4)
//   0x4000-0x5FFF  char/tile graphics (mpe-5/4)
//   0x6000-0x7FFF  sprite graphics    (mpb-2/1)
//   0x8000-0xAFFF  parallax bg bitmaps(mpe-3/2/1)
//   0xB000-0xBFFF  6803 sound program (mp-s1.1a -> sound board)
//
// See PORTING.md for the full runbook.
// =============================================================================

`default_nettype none

module core_top (

// ── Physical connections ──────────────────────────────────────────────────────

input  wire        clk_74a,
input  wire        clk_74b,

// Cartridge (unused)
inout  wire [7:0]  cart_tran_bank2,    output wire cart_tran_bank2_dir,
inout  wire [7:0]  cart_tran_bank3,    output wire cart_tran_bank3_dir,
inout  wire [7:0]  cart_tran_bank1,    output wire cart_tran_bank1_dir,
inout  wire [7:4]  cart_tran_bank0,    output wire cart_tran_bank0_dir,
inout  wire        cart_tran_pin30,    output wire cart_tran_pin30_dir,
output wire        cart_pin30_pwroff_reset,
inout  wire        cart_tran_pin31,    output wire cart_tran_pin31_dir,

// IR (unused)
input  wire        port_ir_rx,
output wire        port_ir_tx,
output wire        port_ir_rx_disable,

// Link port (unused)
inout  wire        port_tran_si,       output wire port_tran_si_dir,
inout  wire        port_tran_so,       output wire port_tran_so_dir,
inout  wire        port_tran_sck,      output wire port_tran_sck_dir,
inout  wire        port_tran_sd,       output wire port_tran_sd_dir,

// PSRAM (unused)
output wire [21:16] cram0_a,    inout  wire [15:0] cram0_dq,
input  wire          cram0_wait, output wire        cram0_clk,
output wire          cram0_adv_n, output wire       cram0_cre,
output wire          cram0_ce0_n, output wire       cram0_ce1_n,
output wire          cram0_oe_n,  output wire       cram0_we_n,
output wire          cram0_ub_n,  output wire       cram0_lb_n,

output wire [21:16] cram1_a,    inout  wire [15:0] cram1_dq,
input  wire          cram1_wait, output wire        cram1_clk,
output wire          cram1_adv_n, output wire       cram1_cre,
output wire          cram1_ce0_n, output wire       cram1_ce1_n,
output wire          cram1_oe_n,  output wire       cram1_we_n,
output wire          cram1_ub_n,  output wire       cram1_lb_n,

// SDRAM (unused)
output wire [12:0] dram_a,    output wire [1:0]  dram_ba,
inout  wire [15:0] dram_dq,   output wire [1:0]  dram_dqm,
output wire        dram_clk,  output wire        dram_cke,
output wire        dram_ras_n, output wire       dram_cas_n,
output wire        dram_we_n,

// SRAM (unused)
output wire [16:0] sram_a,    inout  wire [15:0] sram_dq,
output wire        sram_oe_n, output wire        sram_we_n,
output wire        sram_ub_n, output wire        sram_lb_n,

// Misc physical
input  wire        vblank,
output wire        vpll_feed,
output wire        dbg_tx,
input  wire        dbg_rx,
output wire        user1,
input  wire        user2,
inout  wire        aux_sda,
output wire        aux_scl,

// ── Logical connections (to/from apf_top) ────────────────────────────────────

// Video (24-bit RGB + sync, synchronous to video_rgb_clock)
output wire [23:0] video_rgb,
output wire        video_rgb_clock,
output wire        video_rgb_clock_90,
output wire        video_de,
output wire        video_skip,
output wire        video_vs,
output wire        video_hs,

// Audio I2S
output wire        audio_mclk,
input  wire        audio_adc,
output wire        audio_dac,
output wire        audio_lrck,

// APF bridge bus (synchronous to clk_74a)
output wire        bridge_endian_little,
input  wire [31:0] bridge_addr,
input  wire        bridge_rd,
output reg  [31:0] bridge_rd_data,
input  wire        bridge_wr,
input  wire [31:0] bridge_wr_data,

// Controller inputs
input  wire [31:0] cont1_key,
input  wire [31:0] cont2_key,
input  wire [31:0] cont3_key,
input  wire [31:0] cont4_key,
input  wire [31:0] cont1_joy,
input  wire [31:0] cont2_joy,
input  wire [31:0] cont3_joy,
input  wire [31:0] cont4_joy,
input  wire [15:0] cont1_trig,
input  wire [15:0] cont2_trig,
input  wire [15:0] cont3_trig,
input  wire [15:0] cont4_trig

);

// ── Tie off unused physical ports ────────────────────────────────────────────
assign port_ir_tx              = 1'b0;
assign port_ir_rx_disable      = 1'b1;

assign cart_tran_bank3         = 8'hZZ;   assign cart_tran_bank3_dir     = 1'b0;
assign cart_tran_bank2         = 8'hZZ;   assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hZZ;   assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0         = 4'hF;    assign cart_tran_bank0_dir     = 1'b1;
assign cart_tran_pin30         = 1'b0;    assign cart_tran_pin30_dir     = 1'bZ;
assign cart_pin30_pwroff_reset = 1'b0;
assign cart_tran_pin31         = 1'bZ;    assign cart_tran_pin31_dir     = 1'b0;

assign port_tran_so            = 1'bZ;    assign port_tran_so_dir        = 1'b0;
assign port_tran_si            = 1'bZ;    assign port_tran_si_dir        = 1'b0;
assign port_tran_sck           = 1'bZ;    assign port_tran_sck_dir       = 1'b0;
assign port_tran_sd            = 1'bZ;    assign port_tran_sd_dir        = 1'b0;

assign cram0_a = 6'h0;  assign cram0_dq = 16'hZZZZ; assign cram0_clk = 1'b0;
assign cram0_adv_n = 1'b1; assign cram0_cre = 1'b0;
assign cram0_ce0_n = 1'b1; assign cram0_ce1_n = 1'b1;
assign cram0_oe_n = 1'b1; assign cram0_we_n = 1'b1;
assign cram0_ub_n = 1'b1; assign cram0_lb_n = 1'b1;

assign cram1_a = 6'h0;  assign cram1_dq = 16'hZZZZ; assign cram1_clk = 1'b0;
assign cram1_adv_n = 1'b1; assign cram1_cre = 1'b0;
assign cram1_ce0_n = 1'b1; assign cram1_ce1_n = 1'b1;
assign cram1_oe_n = 1'b1; assign cram1_we_n = 1'b1;
assign cram1_ub_n = 1'b1; assign cram1_lb_n = 1'b1;

assign dram_a = 13'h0; assign dram_ba = 2'h0; assign dram_dq = 16'hZZZZ;
assign dram_dqm = 2'h3; assign dram_clk = 1'b0; assign dram_cke = 1'b0;
assign dram_ras_n = 1'b1; assign dram_cas_n = 1'b1; assign dram_we_n = 1'b1;

assign sram_a = 17'h0; assign sram_dq = 16'hZZZZ;
assign sram_oe_n = 1'b1; assign sram_we_n = 1'b1;
assign sram_ub_n = 1'b1; assign sram_lb_n = 1'b1;

assign vpll_feed = 1'bZ;
assign dbg_tx    = 1'bZ;
assign user1     = 1'bZ;
assign aux_scl   = 1'bZ;

assign bridge_endian_little = 1'b0;  // big-endian

// ── PLL — 74.25 MHz → clk_sys / clk_vid / clk_vid_90 / clk_snd ──────────────
// Moon Patrol (Irem M52) clock plan, matching the MiSTer core:
//   clk_sys    = 30.000000 MHz  -> target_top.clock_30   (Z80 main + platform)
//   clk_vid    =  6.000000 MHz  -> target_top.clock_v    AND Pocket pixel clock
//   clk_vid_90 =  6.000000 MHz @90°  -> Pocket DDR pixel clock (video_rgb_clock_90)
//   clk_snd    =  3.582089 MHz  -> target_top.clock_3p58 (6803 + YM2149 + MSM5205)
// REGENERATE mf_pllbase in Quartus IP Catalog for these 4 outputs (74.25 ref).
// clk_snd needs fractional mode (3.582089 MHz is not an integer divide of 74.25).
wire clk_sys;       // 30.000000 MHz — game logic / Z80 main
wire clk_vid;       //  6.000000 MHz — pixel clock (0°), also clock_v
wire clk_vid_90;    //  6.000000 MHz — pixel clock (90°, for APF DDR output)
wire clk_snd;       //  3.582089 MHz — sound subsystem clock
wire pll_locked;
wire pll_locked_s;

mf_pllbase mp1 (
    .refclk   (clk_74a),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .outclk_1 (clk_vid),
    .outclk_2 (clk_vid_90),
    .outclk_3 (clk_snd),
    .locked   (pll_locked)
);

// Synchronise pll_locked to clk_74a (bridge domain)
synch_3 s_pll (pll_locked, pll_locked_s, clk_74a);

// ── APF bridge command handler ────────────────────────────────────────────────
wire        reset_n;
wire [31:0] cmd_bridge_rd_data;

wire        status_boot_done  = pll_locked_s;
wire        status_setup_done = rom_loaded_s;  // high once ROM is in
wire        status_running    = 1'b1;          // core always reports running to APF

wire        dataslot_requestread;
wire [15:0] dataslot_requestread_id;
wire        dataslot_requestread_ack  = 1'b1;
wire        dataslot_requestread_ok   = 1'b1;

wire        dataslot_requestwrite;
wire [15:0] dataslot_requestwrite_id;
wire [31:0] dataslot_requestwrite_size;
wire        dataslot_requestwrite_ack = 1'b1;
wire        dataslot_requestwrite_ok  = 1'b1;

wire        dataslot_update;
wire [15:0] dataslot_update_id;
wire [31:0] dataslot_update_size;
wire        dataslot_allcomplete;

wire [31:0] rtc_epoch_seconds;
wire [31:0] rtc_date_bcd;
wire [31:0] rtc_time_bcd;
wire        rtc_valid;

wire        savestate_supported = 1'b0;
wire [31:0] savestate_addr      = 32'h0;
wire [31:0] savestate_size      = 32'h0;
wire [31:0] savestate_maxloadsize = 32'h0;
wire        savestate_start;
wire        savestate_start_ack   = 1'b0;
wire        savestate_start_busy  = 1'b0;
wire        savestate_start_ok    = 1'b0;
wire        savestate_start_err   = 1'b0;
wire        savestate_load;
wire        savestate_load_ack    = 1'b0;
wire        savestate_load_busy   = 1'b0;
wire        savestate_load_ok     = 1'b0;
wire        savestate_load_err    = 1'b0;
wire        osnotify_inmenu;

reg         target_dataslot_read    = 1'b0;
reg         target_dataslot_write   = 1'b0;
reg         target_dataslot_getfile = 1'b0;
reg         target_dataslot_openfile= 1'b0;
wire        target_dataslot_ack;
wire        target_dataslot_done;
wire [2:0]  target_dataslot_err;
reg  [15:0] target_dataslot_id         = 16'h0;
reg  [31:0] target_dataslot_slotoffset  = 32'h0;
reg  [31:0] target_dataslot_bridgeaddr  = 32'h0;
reg  [31:0] target_dataslot_length      = 32'h0;
wire [31:0] target_buffer_param_struct;
wire [31:0] target_buffer_resp_struct;

wire [9:0]  datatable_addr;
wire        datatable_wren;
wire [31:0] datatable_data;
wire [31:0] datatable_q;

core_bridge_cmd icb (
    .clk                      (clk_74a),
    .reset_n                  (reset_n),
    .bridge_endian_little      (bridge_endian_little),
    .bridge_addr               (bridge_addr),
    .bridge_rd                 (bridge_rd),
    .bridge_rd_data            (cmd_bridge_rd_data),
    .bridge_wr                 (bridge_wr),
    .bridge_wr_data            (bridge_wr_data),
    .status_boot_done          (status_boot_done),
    .status_setup_done         (status_setup_done),
    .status_running            (status_running),
    .dataslot_requestread      (dataslot_requestread),
    .dataslot_requestread_id   (dataslot_requestread_id),
    .dataslot_requestread_ack  (dataslot_requestread_ack),
    .dataslot_requestread_ok   (dataslot_requestread_ok),
    .dataslot_requestwrite     (dataslot_requestwrite),
    .dataslot_requestwrite_id  (dataslot_requestwrite_id),
    .dataslot_requestwrite_size(dataslot_requestwrite_size),
    .dataslot_requestwrite_ack (dataslot_requestwrite_ack),
    .dataslot_requestwrite_ok  (dataslot_requestwrite_ok),
    .dataslot_update           (dataslot_update),
    .dataslot_update_id        (dataslot_update_id),
    .dataslot_update_size      (dataslot_update_size),
    .dataslot_allcomplete      (dataslot_allcomplete),
    .rtc_epoch_seconds         (rtc_epoch_seconds),
    .rtc_date_bcd              (rtc_date_bcd),
    .rtc_time_bcd              (rtc_time_bcd),
    .rtc_valid                 (rtc_valid),
    .savestate_supported       (savestate_supported),
    .savestate_addr            (savestate_addr),
    .savestate_size            (savestate_size),
    .savestate_maxloadsize     (savestate_maxloadsize),
    .savestate_start           (savestate_start),
    .savestate_start_ack       (savestate_start_ack),
    .savestate_start_busy      (savestate_start_busy),
    .savestate_start_ok        (savestate_start_ok),
    .savestate_start_err       (savestate_start_err),
    .savestate_load            (savestate_load),
    .savestate_load_ack        (savestate_load_ack),
    .savestate_load_busy       (savestate_load_busy),
    .savestate_load_ok         (savestate_load_ok),
    .savestate_load_err        (savestate_load_err),
    .osnotify_inmenu           (osnotify_inmenu),
    .target_dataslot_read      (target_dataslot_read),
    .target_dataslot_write     (target_dataslot_write),
    .target_dataslot_getfile   (target_dataslot_getfile),
    .target_dataslot_openfile  (target_dataslot_openfile),
    .target_dataslot_ack       (target_dataslot_ack),
    .target_dataslot_done      (target_dataslot_done),
    .target_dataslot_err       (target_dataslot_err),
    .target_dataslot_id        (target_dataslot_id),
    .target_dataslot_slotoffset(target_dataslot_slotoffset),
    .target_dataslot_bridgeaddr(target_dataslot_bridgeaddr),
    .target_dataslot_length    (target_dataslot_length),
    .target_buffer_param_struct(target_buffer_param_struct),
    .target_buffer_resp_struct (target_buffer_resp_struct),
    .datatable_addr            (datatable_addr),
    .datatable_wren            (datatable_wren),
    .datatable_data            (datatable_data),
    .datatable_q               (datatable_q)
);

// Bridge read data mux (clk_74a domain)
always @(*) begin
    casex (bridge_addr)
        32'hF8xxxxxx: bridge_rd_data = cmd_bridge_rd_data;
        default:      bridge_rd_data = 32'h0;
    endcase
end

// ── ROM loading via APF bridge ────────────────────────────────────────────────
// Uses Galaga reference's data_loader (dcfifo CDC). Bridge writes captured in
// clk_74a, output dn_* drives are synchronous to clk_sys (where target_top BRAMs
// live). dcfifo handles the clock-domain crossing safely.

wire [15:0] dn_addr;
wire [7:0]  dn_data;
wire        dn_wr;
reg         rom_loaded_74 = 1'b0;
wire        rom_loaded;
wire        rom_loaded_s = rom_loaded_74;  // clk_74a domain, drives status_setup_done

synch_3 s_rom_to_sys (rom_loaded_74, rom_loaded, clk_sys);

data_loader #(
    .ADDRESS_MASK_UPPER_4  (4'h0),   // accept bridge_addr[31:28] == 0
    .ADDRESS_SIZE          (15),     // 16-bit byte address (16-bit dn_addr)
    .OUTPUT_WORD_SIZE      (1)       // 8-bit byte writes
) u_rom_loader (
    .clk_74a              (clk_74a),
    .clk_memory           (clk_sys),
    .bridge_wr            (bridge_wr),
    .bridge_endian_little (bridge_endian_little),
    .bridge_addr          (bridge_addr),
    .bridge_wr_data       (bridge_wr_data),
    .write_en             (dn_wr),
    .write_addr           (dn_addr),
    .write_data           (dn_data)
);

// ROM is loaded when the APF framework signals all data slots complete.
always @(posedge clk_74a) begin
    if (dataslot_allcomplete)
        rom_loaded_74 <= 1'b1;
end

// ── Reset ─────────────────────────────────────────────────────────────────────
// Game runs only when the host has released reset (reset_n) AND the PLL is
// locked AND the ROM is loaded (and a brief settling counter has expired).
wire reset_n_sys;
synch_3 s_resetn (reset_n, reset_n_sys, clk_sys);

reg [7:0] reset_ctr = 8'hFF;
wire      game_reset_n = (reset_ctr == 8'h0) && rom_loaded && reset_n_sys;

always @(posedge clk_sys) begin
    if (!pll_locked)
        reset_ctr <= 8'hFF;
    else if (reset_ctr != 8'h0)
        reset_ctr <= reset_ctr - 1'd1;
end

// (No clock-enable dividers: target_top takes three real PLL clocks —
//  clock_30 / clock_v(6) / clock_3p58 — and derives its own internal enables.)

// ── Controller mapping ────────────────────────────────────────────────────────
// target_top JOY bus is ACTIVE-HIGH (it inverts internally to active-low JAMMA).
// APF cont*_key bits are also active-high (1 = pressed), so JOY = key bits direct.
// MiSTer bit order (Arcade-MoonPatrol.sv):
//   JOY = {coin, start, jump, fire, up, down, left, right}
// APF cont_key: [0]up [1]down [2]left [3]right [4]A [5]B [14]select [15]start
//
// Moon Patrol is a 2-way horizontal game: drive = left/right, two buttons
// (fire + jump). up/down are passed through but unused by the game.
wire [7:0] JOY = {
    cont1_key[14],    // [7] coin   = SELECT
    cont1_key[15],    // [6] start  = START
    cont1_key[5],     // [5] jump   = B
    cont1_key[4],     // [4] fire   = A
    cont1_key[0],     // [3] up
    cont1_key[1],     // [2] down
    cont1_key[2],     // [1] left
    cont1_key[3]      // [0] right
};
wire [7:0] JOY2 = {
    cont2_key[14],    // [7] coin2
    cont2_key[15],    // [6] start2
    cont2_key[5],     // [5] jump
    cont2_key[4],     // [4] fire
    cont2_key[0],     // [3] up
    cont2_key[1],     // [2] down
    cont2_key[2],     // [1] left
    cont2_key[3]      // [0] right
};

// ── Moon Patrol game core (PACE-framework target_top, VHDL) ────────────────────
// target_top bundles the whole game: pace (Z80 main + Irem M52 video) AND
// moon_patrol_sound_board (6803 + 2x YM2149 + MSM5205). Instantiated by entity
// name; Quartus resolves the mixed Verilog/VHDL binding.
wire [3:0] vid_r, vid_g, vid_b;
wire       vid_hs, vid_vs, vid_hblank, vid_vblank;
wire signed [12:0] game_audio;

target_top moonpatrol (
    .clock_30   (clk_sys),       // 30 MHz
    .clock_v    (clk_vid),       // 6 MHz pixel clock
    .clock_3p58 (clk_snd),       // 3.582 MHz sound
    .reset      (~game_reset_n), // active-high reset

    .dn_addr    (dn_addr),
    .dn_data    (dn_data),
    .dn_wr      (dn_wr),

    .AUDIO      (game_audio),

    .JOY        (JOY),
    .JOY2       (JOY2),

    .VGA_R      (vid_r),
    .VGA_G      (vid_g),
    .VGA_B      (vid_b),
    .VGA_HS     (vid_hs),
    .VGA_VS     (vid_vs),
    .VGA_HBLANK (vid_hblank),
    .VGA_VBLANK (vid_vblank),

    .palmode    (1'b0),          // 0 = native ~56.7 Hz (not PAL 50 Hz)
    .hs_offset  (4'h0),
    .vs_offset  (4'h0),

    .pause      (1'b0),

    // hiscore interface unused
    .hs_address  (11'h0),
    .hs_data_out (),
    .hs_data_in  (8'h0),
    .hs_write    (1'b0)
);

// ── Video output ──────────────────────────────────────────────────────────────
// Irem M52 outputs 4+4+4 bit RGB. Expand to 24-bit by nibble replication.

wire [7:0] rgb_r = {vid_r, vid_r};   // 4 → 8 bit
wire [7:0] rgb_g = {vid_g, vid_g};
wire [7:0] rgb_b = {vid_b, vid_b};

wire [23:0] rgb_out = (vid_hblank | vid_vblank) ? 24'h0 : {rgb_r, rgb_g, rgb_b};

// Sample video signals on pixel clock rising edge
reg [23:0] vid_rgb_r;
reg        vid_hs_r, vid_vs_r, vid_de_r;

always @(posedge clk_vid) begin
    vid_rgb_r <= rgb_out;
    vid_hs_r  <= vid_hs;
    vid_vs_r  <= vid_vs;
    vid_de_r  <= ~(vid_hblank | vid_vblank);
end

// APF expects 24-bit RGB at video_rgb_clock rate.
// apf_top DDR-encodes upper 12 bits on rising edge, lower 12 on falling edge.
assign video_rgb          = vid_rgb_r;
assign video_rgb_clock    = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;
assign video_de           = vid_de_r;
assign video_skip         = 1'b0;
assign video_vs           = vid_vs_r;
assign video_hs           = vid_hs_r;

// ── Audio (APF I2S via sound_i2s) ─────────────────────────────────────────────
// STEP 2 (playable-silent): the sound board IS compiled in (it lives inside
// target_top) and produces game_audio, but we feed the I2S silence so first
// boot is judged on video/CPU alone — the MSM5205 ADPCM timing is the one risky
// piece and we don't want it confounding bring-up.
//
// STEP 3 (enable sound): set AUDIO_ENABLE = 1'b1. game_audio is signed 13-bit;
// take the top CHANNEL_WIDTH bits with SIGNED_INPUT=1. (Verify clk_snd is a real
// 3.582 MHz PLL output and chase the MSM5205 S1/S2 timing if ADPCM is off.)
localparam AUDIO_ENABLE = 1'b1;

wire signed [15:0] audio_sample =
    AUDIO_ENABLE ? {game_audio, 3'b000} : 16'sd0;  // 13 → 16 bit

sound_i2s #(
    .CHANNEL_WIDTH (16),
    .SIGNED_INPUT  (1)
) u_sound_i2s (
    .clk_74a    (clk_74a),
    .clk_audio  (clk_sys),
    .audio_l    (audio_sample),
    .audio_r    (audio_sample),
    .audio_mclk (audio_mclk),
    .audio_dac  (audio_dac),
    .audio_lrck (audio_lrck)
);

endmodule
