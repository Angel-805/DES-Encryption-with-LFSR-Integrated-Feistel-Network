`timescale 1ns/100ps

// Simplified Feistel function for debugging
module Feistel(
    input  [31:0] left_in,
    input  [31:0] right_in,
    input  [47:0] round_key,
    output [31:0] left_out,
    output [31:0] right_out
);

// Simple expansion: just duplicate some bits to go from 32 to 48
wire [47:0] R_expanded;
assign R_expanded = {right_in[31:16], right_in[31:16], right_in[15:0]};

// XOR with round key
wire [47:0] xored = R_expanded ^ round_key;

// Simple compression: XOR the 48 bits down to 32
// Split into 6 bytes, XOR pairs together
wire [31:0] compressed;
assign compressed = {
    xored[47:40] ^ xored[39:32],
    xored[31:24] ^ xored[23:16],
    xored[15:8]  ^ xored[7:0],
    8'hAA  // Fixed padding for now
};

// Simple substitution - just rotate and XOR for testing
wire [31:0] substituted;
assign substituted = {compressed[30:0], compressed[31]} ^ 32'h5A5A5A5A;

// Output: swap and XOR
assign left_out = right_in;
assign right_out = left_in ^ substituted;

// Debug output - only print once per clock when values change
reg [31:0] prev_left, prev_right;
reg [47:0] prev_key;

always @(left_in or right_in or round_key) begin
    if (left_in !== prev_left || right_in !== prev_right || round_key !== prev_key) begin
        if (round_key !== 48'hxxxxxxxxxxxx && round_key !== 48'h0) begin
            $display("Feistel: L_in=%h R_in=%h Key=%h -> L_out=%h R_out=%h F=%h", 
                     left_in, right_in, round_key, left_out, right_out, substituted);
        end
        prev_left <= left_in;
        prev_right <= right_in;
        prev_key <= round_key;
    end
end

endmodule