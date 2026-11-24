`timescale 1ns/1ps
//============================================================================
//  Simulation-only stand-ins for things Icarus cannot elaborate.
//  Never listed in ap_core.qsf; simulation only.
//
//  T80s is VHDL and there is no free VHDL simulator installed, so it is
//  stubbed unconditionally -- see the CPU note in sim/README.
//
//  LINEBUF wraps an altsyncram megafunction. Quartus ships a simulation model
//  for it (eda/sim_lib/altera_mf.v) and tools/sim.py uses the real thing when
//  it can find it. The fallback below is compiled only when it cannot, so a
//  machine without Quartus can still run the suite -- at the cost of testing
//  a hand-written model instead of the megafunction.
//============================================================================

`ifdef LINEBUF_STUB
module LINEBUF
(
    input             clock_a,
    input      [9:0]  address_a,
    input      [8:0]  data_a,
    input             wren_a,
    output reg [8:0]  q_a,

    input             clock_b,
    input      [9:0]  address_b,
    input      [8:0]  data_b,
    input             wren_b
);

reg [8:0] core [0:1023];
integer i;
initial for (i = 0; i < 1024; i = i + 1) core[i] = 9'h0;

always @(posedge clock_a) begin
    q_a <= core[address_a];
    if (wren_a) core[address_a] <= 9'h0;
end

always @(posedge clock_b) if (wren_b) core[address_b] <= data_b;

endmodule
`endif


// Inert Z80. Holds every bus strobe inactive so the surrounding glue is quiet;
// the CPU-clock testbench measures the divider feeding CLK, not the core.
module T80s
#(
    parameter T2Write = 1
)
(
    input         RESET_n,
    input         CLK,
    input         CEN,
    input         OUT0,
    input         WAIT_n,
    input         INT_n,
    input         NMI_n,
    input         BUSRQ_n,
    input  [7:0]  DI,
    output        M1_n,
    output        MREQ_n,
    output        IORQ_n,
    output        RD_n,
    output        WR_n,
    output        RFSH_n,
    output        HALT_n,
    output        BUSAK_n,
    output [15:0] A,
    output [7:0]  DO
);

assign M1_n   = 1'b1;
assign MREQ_n = 1'b1;
assign IORQ_n = 1'b1;
assign RD_n   = 1'b1;
assign WR_n   = 1'b1;
assign RFSH_n = 1'b1;
assign HALT_n = 1'b1;
assign BUSAK_n= 1'b1;
assign A      = 16'h0000;
assign DO     = 8'h00;

endmodule
