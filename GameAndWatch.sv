//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2022, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Copyright (c) 2022, OpenGateware authors and contributors
// Copyright (c) 2017, Alexey Melnikov <pour.garbage@gmail.com>
// Copyright (c) 2015, Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//
//------------------------------------------------------------------------------
// MiSTer framework glue logic.
// Instantiated by the framework top-level: sys/sys_top.v
//------------------------------------------------------------------------------

module emu (
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [45:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output [1:0]  VGA_SL,
    output        VGA_SCALER, // Force VGA scaler
    output        VGA_DISABLE, // analog out is off

    input  [11:0] HDMI_WIDTH,
    input  [11:0] HDMI_HEIGHT,
    output        HDMI_FREEZE,
    output        HDMI_BLACKOUT,
    output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
    // Use framebuffer in DDRAM
    // FB_FORMAT:
    //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
    //    [3]   : 0=16bits 565 1=16bits 1555
    //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
    //
    // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
    output        FB_EN,
    output  [4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output  [7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,
`endif
`endif

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO, // 24.576 MHz
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //High latency DDR3 RAM interface
    //Use for non-critical time purposes
    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output  [7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output  [7:0] DDRAM_BE,
    output        DDRAM_WE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
    //Secondary SDRAM
    //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
    input         SDRAM2_EN,
    output        SDRAM2_CLK,
    output [12:0] SDRAM2_A,
    output  [1:0] SDRAM2_BA,
    inout  [15:0] SDRAM2_DQ,
    output        SDRAM2_nCS,
    output        SDRAM2_nCAS,
    output        SDRAM2_nRAS,
    output        SDRAM2_nWE,
`endif

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + USER_PP, USER_IN/OUT widened to 8 bits
    output        USER_OSD,
    output  [7:0] USER_PP,
    input   [7:0] USER_IN,
    output  [7:0] USER_OUT,
    // [MiSTer-DB9 END]

    input         OSD_STATUS
);

  assign ADC_BUS = 'Z;
  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driver
  assign USER_PP = USER_PP_DRIVE;
  // [MiSTer-DB9 END]

  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
  wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
  wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
  wire         joy_2p          = 1'b0;            // 1P-only: joy_2p unused
  wire         snac_active     = 1'b0;
  wire         mt32_primary_active = 1'b0;
  wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
  wire         joy_db9md_en    = (joy_type == 2'd2);
  wire         joy_db15_en     = (joy_type == 2'd3);
  wire         joy_any_en      = |joy_type;
  wire   [2:0] JOY_FLAG        = {joy_db9md_en, joy_db15_en, joy_2p};
  // [MiSTer-DB9 END]

  // [MiSTer-DB9-Pro BEGIN] - Saturn key gate
  wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
  // [MiSTer-DB9-Pro END]

  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
  wire   [7:0] USER_OUT_DRIVE;
  wire   [7:0] USER_PP_DRIVE;
  wire  [15:0] joydb_1, joydb_2;
  wire         joydb_1ena, joydb_2ena;
  wire         pad_1_6btn, pad_2_6btn;
  wire  [15:0] joy_raw_payload;

  // [MiSTer-DB9 BEGIN] - DB9 programmable-remap matrix wires
  // joydb_*_mapped = MiSTer-standard joystick words (consumed in Layer B);
  // db9_remap_* = 0xFD selector stream driven by the hps_io instance.
  wire  [15:0] joydb_1_mapped, joydb_2_mapped;
  wire         db9_remap_cmd;
  wire   [5:0] db9_remap_byte_cnt;
  wire  [15:0] db9_remap_din;
  // [MiSTer-DB9 END]
  joydb joydb (
    .clk             ( CLK_JOY         ),
    .clk_sys         ( clk_sys_99_287            ),
    .USER_IN         ( USER_IN         ),
    .OSD_STATUS          ( OSD_STATUS          ),
    .snac_active         ( snac_active         ),
    .mt32_primary_active ( mt32_primary_active ),
    .joy_type        ( joy_type        ),
    .joy_2p          ( joy_2p          ),
    .saturn_unlocked ( saturn_unlocked ),
    .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
    .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
    .USER_OSD        ( USER_OSD        ),
    .joydb_1         ( joydb_1         ),
    .joydb_2         ( joydb_2         ),
    .joydb_1ena      ( joydb_1ena      ),
    .joydb_2ena      ( joydb_2ena      ),
    .remap_cmd       ( db9_remap_cmd      ),
    .remap_byte_cnt  ( db9_remap_byte_cnt ),
    .remap_din       ( db9_remap_din      ),
    .joydb_1_mapped  ( joydb_1_mapped     ),
    .joydb_2_mapped  ( joydb_2_mapped     ),
    .pad_1_6btn      ( pad_1_6btn      ),
    .pad_2_6btn      ( pad_2_6btn      ),
    .joy_raw         ( joy_raw_payload )
  );

  assign USER_OUT = USER_OUT_DRIVE;
  // [MiSTer-DB9 END]
  assign {UART_RTS, UART_TXD, UART_DTR} = 0;
  assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
  assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

  assign VGA_F1 = 0;
  assign VGA_SCALER = 0;
  assign VGA_DISABLE = 0;
  assign HDMI_FREEZE = 0;
  assign HDMI_BLACKOUT = 0;
  assign HDMI_BOB_DEINT = 0;

`ifdef MISTER_FB
  assign FB_EN = 0;
  assign FB_FORMAT = 0;
  assign FB_WIDTH = 0;
  assign FB_HEIGHT = 0;
  assign FB_BASE = 0;
  assign FB_STRIDE = 0;
  assign FB_FORCE_BLANK = 0;

`ifdef MISTER_FB_PALETTE
  assign FB_PAL_CLK = 0;
  assign FB_PAL_ADDR = 0;
  assign FB_PAL_DOUT = 0;
  assign FB_PAL_WR = 0;
`endif
`endif

`ifdef MISTER_DUAL_SDRAM
  assign {SDRAM2_CLK, SDRAM2_A, SDRAM2_BA, SDRAM2_nCS, SDRAM2_nCAS, SDRAM2_nRAS, SDRAM2_nWE} = 'Z;
  assign SDRAM2_DQ = 'Z;
`endif

  assign AUDIO_MIX = 0;

  assign LED_DISK = 0;
  assign LED_POWER = 0;
  assign LED_USER = 0;
  assign BUTTONS[1] = 0;

  `include "build_id.v"

  localparam CONF_STR = {
    "Game and Watch;;",
    "FS0,gnw,Load ROM;",
    "-;",
    "O[10],Native Video,360x240 CRT,720x720;",
    "-;",
    "O[5:2],Inactive LCD Alpha,Off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%,100%;",
    "-;",
    "O[1],Accurate LCD Timing,Off,On;",
    "-;",
    "O[11],Audio,On,Mute;",
`ifdef CORE_ENABLE_DEBUG_OVERLAY
    "-;",
    "O[6],Debug Video,Off,On;",
    "O[8:7],Debug View,Events,CPU,Melody,Core;",
    "O[9],Debug Freeze,Off,On;",
    "-;",
`endif
    "-;",
    // [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation; 1P-only)
    "O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
    // [MiSTer-DB9-Pro END]
    "R[0],Reset;",
    "J1,Btn 1/R Joy Down,Btn 2/R Joy Right,Btn 3/R Joy Left,Btn 4/R Joy Up,Time/Pause/Status,Alarm,Game A/Power On,Game B/Power Off,Sound/Minute,ACL;",
    "jn,B,A,Y,X,L,R,Select,Start;",
    "v,0;",
    "V,v",
    `BUILD_DATE
  };

  wire clk_sys_99_287;
  wire pll_core_locked;
  wire clk_video_54;
  wire pll_video_locked;

  pll pll (
      .refclk  (CLK_50M),
      .rst     (RESET),
      .outclk_0(clk_sys_99_287),
      .outclk_1(),
      .locked  (pll_core_locked)
  );

  // Direct Video transports the CRT raster on the canonical 54.000 MHz SD
  // clock. Rendering remains on the mapped 98.3203125 MHz core clock below; a
  // packet FIFO crosses only complete logical pixels into this output domain.
  // The video PLL is free-running. Its lock participates in the transport's
  // asynchronously asserted, synchronously released reset instead of being
  // restarted by the emulated machine reset.
  video_pll_54 video_pll (
      .refclk_50  (CLK_50M),
      .reset      (1'b0),
      .clk_video_54(clk_video_54),
      .locked     (pll_video_locked)
  );

  wire video_transport_async_reset = RESET || !pll_core_locked || !pll_video_locked;
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
  reg [2:0] video_transport_reset_pipe = 3'b111;
  always @(posedge clk_video_54 or posedge video_transport_async_reset) begin
    if (video_transport_async_reset) begin
      video_transport_reset_pipe <= 3'b111;
    end else begin
      video_transport_reset_pipe <= {video_transport_reset_pipe[1:0], 1'b0};
    end
  end
  wire video_transport_reset = video_transport_reset_pipe[2];

  wire active_crt_video;
  wire hold_video;
  wire new_vmode;
  wire transport_active_crt;

  // video_mode_control emits a toggle only after a mode switch has completed
  // in the source domain. Synchronize that notification before handing it to
  // hps_io's fixed-54 MHz video-domain mode calculator.
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
  reg [1:0] new_vmode_video_pipe = 2'b00;
  always @(posedge clk_video_54) begin
    new_vmode_video_pipe <= {new_vmode_video_pipe[0], new_vmode};
  end
  wire new_vmode_video = new_vmode_video_pipe[1];

  wire [127:0] status;
  wire [  1:0] hps_buttons;
  wire [ 21:0] gamma_bus;
  wire         forced_scandoubler;

  wire        ioctl_download;
  wire        ioctl_upload;
  wire        ioctl_upload_req = 0;
  wire [15:0] ioctl_index;
  wire        ioctl_wr;
  wire        ioctl_wait;
  wire [26:0] ioctl_addr;
  wire [15:0] ioctl_dout;
  wire [15:0] ioctl_din = 0;

  wire [10:0] ps2_key;
  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USB-side joysticks + joydb mux
  wire [31:0] joystick_0_USB, joystick_1_USB;
  wire [31:0] joystick_0 = joydb_1ena ? (OSD_STATUS ? 32'b0 : joydb_1_mapped[15:0]) : joystick_0_USB;
  wire [31:0] joystick_1 = joydb_2ena ? (OSD_STATUS ? 32'b0 : joydb_2_mapped[15:0]) : (joydb_1ena ? joystick_0_USB : joystick_1_USB);
  // [MiSTer-DB9 END]

  hps_io #(
      .CONF_STR(CONF_STR),
      .WIDE(1)
  ) hps_io (
      .clk_sys(clk_sys_99_287),
      .HPS_BUS(HPS_BUS),
      .EXT_BUS(),
      .gamma_bus(gamma_bus),

      .buttons(hps_buttons),
      .forced_scandoubler(forced_scandoubler),
      .status(status),
      .status_in(128'd0),
      .status_set(1'b0),
      .status_menumask(16'd0),

      .video_rotated(1'b0),
      .new_vmode(new_vmode_video),

      .info_req(1'b0),
      .info(8'd0),

      .ioctl_upload      (ioctl_upload),
      .ioctl_upload_req  (ioctl_upload_req),
      .ioctl_upload_index(8'd0),
      .ioctl_download    (ioctl_download),
      .ioctl_wr          (ioctl_wr),
      .ioctl_addr        (ioctl_addr),
      .ioctl_dout        (ioctl_dout),
      .ioctl_din         (ioctl_din),
      .ioctl_index       (ioctl_index),
      .ioctl_wait        (ioctl_wait),

      .ps2_key(ps2_key),

      // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: route USB joysticks through joydb mux + joy_raw
      .joystick_0(joystick_0_USB),
      .joystick_1(joystick_1_USB),
      .joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
      // programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
      .db9_remap_cmd(db9_remap_cmd),
      .db9_remap_byte_cnt(db9_remap_byte_cnt),
      .db9_remap_din(db9_remap_din),
      // [MiSTer-DB9 END]
      // [MiSTer-DB9-Pro BEGIN] - Saturn key gate
      .saturn_unlocked(saturn_unlocked)
      // [MiSTer-DB9-Pro END]
  );

  wire external_reset = status[0];
  wire accurate_lcd_timing = status[1];
  wire [3:0] inactive_lcd_alpha_selection = status[5:2];
`ifdef CORE_ENABLE_DEBUG_OVERLAY
  wire debug_video = status[6];
  wire [1:0] debug_view = status[8:7];
  wire debug_freeze = status[9];
`else
  wire debug_video = 1'b0;
  wire [1:0] debug_view = 2'b00;
  wire debug_freeze = 1'b0;
`endif
  wire requested_crt_video = ~status[10];
  wire crt_video = active_crt_video;

  // Aspect ratio follows the mode actually committed by the output bridge,
  // not the independently clocked source-domain request.
  assign VIDEO_ARX = transport_active_crt ? 13'd4 : 13'd1;
  assign VIDEO_ARY = transport_active_crt ? 13'd3 : 13'd1;

  reg [7:0] lcd_off_alpha;

  always_comb begin
    lcd_off_alpha = 0;

    case (inactive_lcd_alpha_selection)
      0: lcd_off_alpha = 0;
      1: lcd_off_alpha = 13;
      2: lcd_off_alpha = 26;
      3: lcd_off_alpha = 51;
      4: lcd_off_alpha = 77;
      5: lcd_off_alpha = 102;
      6: lcd_off_alpha = 128;
      7: lcd_off_alpha = 153;
      8: lcd_off_alpha = 179;
      9: lcd_off_alpha = 204;
      10: lcd_off_alpha = 230;
      11: lcd_off_alpha = 255;
      default: lcd_off_alpha = 0;
    endcase
  end

  reg has_rom = 0;
  reg [25:0] open_osd_timeout = {26{1'b1}};
  reg did_reset = 0;
  reg open_osd = 0;
  reg prev_ioctl_download = 0;

  assign BUTTONS[0] = open_osd;

  always @(posedge clk_sys_99_287) begin
    prev_ioctl_download <= ioctl_download;

    if (~ioctl_download && prev_ioctl_download) begin
      has_rom <= 1;
    end

    if (RESET) begin
      did_reset <= 0;
    end else if (status[0]) begin
      did_reset <= 1;
    end

    if (did_reset && ~status[0]) begin
      open_osd <= 0;

      if (open_osd_timeout > 0) begin
        open_osd_timeout <= open_osd_timeout - 26'd1;

        if (~has_rom) begin
          open_osd <= 1;
        end
      end
    end
  end

  wire signed [15:0] core_audio;
  wire audio_muted = status[11];
  wire source_vsync;
  wire source_hsync;
  wire source_vblank;
  wire source_hblank;
  wire source_de;
  wire source_ce_pix;
  wire [23:0] source_rgb;
  wire source_packet_wr;
  wire [29:0] source_packet;
  wire crt_source_tick_toggle;
  wire native_source_pause;
  wire source_video_held;

  wire vsync;
  wire hsync;
  wire vblank;
  wire hblank;
  wire de;
  wire ce_pix;
  wire [23:0] rgb;

  // Keep the output blank long enough for the largest SDRAM line buffer to
  // refill after its base address changes (2160 16-bit words natively).
  video_mode_control #(
      .SETTLE_CYCLES(4096)
  ) video_mode_control (
      .clk_sys(clk_sys_99_287),
      .reset(RESET),
      .clocks_ready(pll_core_locked && pll_video_locked),
      .request_crt(requested_crt_video),
      .video_vblank(source_vblank),
      .video_held(source_video_held),
      .active_crt(active_crt_video),
      .hold_video(hold_video),
      .new_vmode(new_vmode)
  );

  gameandwatch gameandwatch (
      .clk_sys_99_287(clk_sys_99_287),
      .clk_vid_33_095(clk_sys_99_287),

      .reset(RESET || ioctl_download || ~has_rom || external_reset || hps_buttons[1]),
      .video_blank(RESET || ~has_rom || external_reset || hps_buttons[1]),
      .pll_core_locked(pll_core_locked),

      .button_a(joystick_0[5]),
      .button_b(joystick_0[4]),
      .button_x(joystick_0[7]),
      .button_y(joystick_0[6]),
      .button_aux(joystick_0[13:8]),
      .osd_status(OSD_STATUS),
      .dpad_up(joystick_0[3]),
      .dpad_down(joystick_0[2]),
      .dpad_left(joystick_0[1]),
      .dpad_right(joystick_0[0]),
      .player_two_button_a(joystick_1[5]),
      .player_two_button_b(joystick_1[4]),
      .player_two_button_x(joystick_1[7]),
      .player_two_button_y(joystick_1[6]),
      .player_two_button_aux(joystick_1[13:8]),
      .player_two_dpad_up(joystick_1[3]),
      .player_two_dpad_down(joystick_1[2]),
      .player_two_dpad_left(joystick_1[1]),
      .player_two_dpad_right(joystick_1[0]),

      .ioctl_download(ioctl_download),
      .ioctl_wr(ioctl_wr),
      .ioctl_addr({1'b0, ioctl_addr[24:1]}),
      .ioctl_dout(ioctl_dout),
      .ioctl_wait(ioctl_wait),

      .hsync(source_hsync),
      .vsync(source_vsync),
      .hblank(source_hblank),
      .vblank(source_vblank),
      .de(source_de),
      .ce_pix(source_ce_pix),
      .rgb(source_rgb),
      .source_packet_wr(source_packet_wr),
      .source_packet(source_packet),
      .video_held(source_video_held),

      .audio(core_audio),

      .accurate_lcd_timing(accurate_lcd_timing),
      .lcd_off_alpha(lcd_off_alpha),
      .crt_video(crt_video),
      .hold_video(hold_video),
      .crt_source_tick_async(crt_source_tick_toggle),
      .native_source_pause_async(native_source_pause),

      .debug_video(debug_video),
      .debug_view(debug_view),
      .debug_freeze(debug_freeze),
      .debug_clear(RESET || (ioctl_download && !prev_ioctl_download) || external_reset || hps_buttons[1]),

      .SDRAM_A(SDRAM_A),
      .SDRAM_BA(SDRAM_BA),
      .SDRAM_DQ(SDRAM_DQ),
      .SDRAM_DQM({SDRAM_DQMH, SDRAM_DQML}),
      .SDRAM_CLK(SDRAM_CLK),
      .SDRAM_CKE(SDRAM_CKE),
      .SDRAM_nCS(SDRAM_nCS),
      .SDRAM_nRAS(SDRAM_nRAS),
      .SDRAM_nCAS(SDRAM_nCAS),
      .SDRAM_nWE(SDRAM_nWE)
  );

  wire transport_packet_ready;
  wire [9:0] transport_packet_level_source;
  wire [9:0] transport_packet_level_video;
  wire transport_running;
  wire transport_fault;
  video_transport_54 #(
      .PREFILL_WORDS(512)
  ) video_transport (
      .clk_source(clk_sys_99_287),
      .clk_video_54(clk_video_54),
      .reset(video_transport_reset),
      .crt_mode_async(crt_video),
      .hold_async(hold_video),
      .packet_wr(source_packet_wr),
      .packet_data(source_packet),
      .packet_ready(transport_packet_ready),
      .packet_level_source(transport_packet_level_source),
      .packet_level_video(transport_packet_level_video),
      .crt_source_tick_toggle(crt_source_tick_toggle),
      .native_source_pause(native_source_pause),
      .ce_pixel(ce_pix),
      .hsync(hsync),
      .vsync(vsync),
      .hblank(hblank),
      .vblank(vblank),
      .de(de),
      .rgb(rgb),
      .active_crt_mode(transport_active_crt),
      .running(transport_running),
      .fault(transport_fault)
  );

  // CLK_VIDEO must be a direct PLL clock because the MiSTer framework places
  // its own clock selector after this boundary. CRT mode exposes an actual
  // 360-sample CE /8 transport, giving 2880 active and 3432 total raw clocks
  // at 54 MHz. Native mode remains
  // emitted using an exact-average 32.768 MHz CE, although Direct Video support
  // is intentionally only claimed for the CRT mode.
  assign CLK_VIDEO = clk_video_54;
  assign CE_PIXEL = ce_pix;

  assign VGA_R = rgb[23:16];
  assign VGA_G = rgb[15:8];
  assign VGA_B = rgb[7:0];
  assign VGA_HS = hsync;
  assign VGA_VS = vsync;
  assign VGA_DE = de;
  assign VGA_SL = 2'b00;

  assign AUDIO_S = 1;
  assign AUDIO_L = audio_muted ? 16'sd0 : core_audio;
  assign AUDIO_R = AUDIO_L;

endmodule
