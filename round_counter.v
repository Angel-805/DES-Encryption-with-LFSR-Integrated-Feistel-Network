`timescale 1ns/100ps

// Round counter
module round_counter(
    input clk,
    input rst_n,
    input cnt_rst,
    input count,
    output reg [2:0] round_cnt
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        round_cnt <= 0;
    else if (cnt_rst)
        round_cnt <= 0;
    else if (count)
        round_cnt <= round_cnt + 1;
end

endmodule