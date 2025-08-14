`timescale 1ns/100ps

// right register
module Right_reg(
    input clk, rst, load,
    input [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge rst) begin
    if (rst)
        data_out <= 0;
    else if (load)
        data_out <= data_in;  // load new value
end
endmodule