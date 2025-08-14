`timescale 1ns/100ps

// output register combines result
module Output_reg(
    input clk, rst, load,
    input [31:0] left_in, right_in,
    output reg [63:0] data_out,
    output reg valid
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_out <= 0;
        valid <= 0;
    end 
    else begin
        if (load) begin
                data_out <= {right_in, left_in};  // DES final swap
            valid <= 1;
        end 
        else begin
            valid <= 0;
        end
    end
end
endmodule