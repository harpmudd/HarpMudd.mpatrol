// mf_pllbase.v - PLL wrapper for Moon Patrol (Irem M52) Pocket core
// 74.25 MHz in -> 30 MHz (clk_sys) + 6 MHz (clk_vid) + 6 MHz 90deg (clk_vid_90)
//              + 3.582089 MHz (clk_snd)
`timescale 1 ps / 1 ps
module mf_pllbase (
    input  wire  refclk,
    input  wire  rst,
    output wire  outclk_0,  // 30.000000 MHz - target_top.clock_30
    output wire  outclk_1,  //  6.000000 MHz - pixel clock / clock_v
    output wire  outclk_2,  //  6.000000 MHz 90 deg - APF DDR pixel clock
    output wire  outclk_3,  //  3.582089 MHz - target_top.clock_3p58 (sound)
    output wire  locked
);

mf_pllbase_0002 mf_pllbase_inst (
    .refclk   (refclk),
    .rst      (rst),
    .outclk_0 (outclk_0),
    .outclk_1 (outclk_1),
    .outclk_2 (outclk_2),
    .outclk_3 (outclk_3),
    .locked   (locked)
);

endmodule
