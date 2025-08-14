`timescale 1ns/100ps

// storage for round keys
module Rnd_key_storage #(
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = 4
)(
    input clk,rst,mode,
    input [ADDR_WIDTH-1:0] addr,
    input [47:0] data_in,
    output reg [47:0] data_out
);

// memory array
reg [47:0] mem [0:DEPTH-1];

always @(posedge clk or posedge rst) begin
    if (rst)
        data_out <= 0;
    else if (mode)
        mem[addr] <= data_in;  // write
    else
        data_out <= mem[addr];  // read
end
endmodule