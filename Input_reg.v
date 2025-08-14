`timescale 1ns/100ps

// input register splits data
module Input_reg(
    input clk, rst, load,
    input [63:0] data_in,
    output reg [31:0] left_out, right_out,
    output reg trigger
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        left_out <= 0;
        right_out <= 0;
        trigger <= 0;
    end 
    else begin
        if (load) begin
            left_out <= data_in[63:32];  // upper bits
            right_out <= data_in[31:0];   // lower bits
            trigger <= 1;
        end 
        else begin
            trigger <= 0;
        end
    end
end
endmodule