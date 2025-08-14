`timescale 1ns/100ps

module des_fsm(
    input clk,
    input rst_n,
    input start,
    input enc_dec,      
    input [2:0] round_cnt, // 0-7
    input keys_ready,

    output reg done,
    output reg busy,
    output reg load_d, // load Input_reg for seed
    output reg load_k, // request key gen while not ready
    output reg round,// advance one round
    output reg count, 
    output reg output_sig, // latch Output_reg this cycle

    output reg [2:0] state
);

//addded states for DES std
localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam ROUND = 3'd2;

//new
localparam OUT_LATCH = 3'd3; //assert output_sig here
localparam OUT_DONE = 3'd4; //delay
localparam WAIT = 3'd5; //skipped after seed

reg [2:0] next_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

always @* begin
    
    //default to 0
    //prevents latches
    done = 1'b0;
    busy = 1'b0;
    load_d = 1'b0;
    load_k = 1'b0;
    round = 1'b0;
    count = 1'b0;
    output_sig = 1'b0;
    next_state = state;

   
    case (state)

     //key gen (next state) or jump to rounds
        IDLE: begin
            if (start) begin
                if (keys_ready) begin
                    load_d = 1'b1; // seed input only when keys are ready
                    next_state = ROUND;
                end else begin
                    load_k = 1'b1;
                    next_state = INIT;
                end
            end
        end

        //hold load signal hi to wait for keys
        INIT: begin
            busy   = 1'b1;
            load_k = 1'b1;
            if (keys_ready) begin
                load_d = 1'b1; // seed once keys are ready
                next_state = ROUND;
            end
        end

        //1 round pper cycle, 8 cycles
        ROUND: begin
            busy  = 1'b1;
            round = 1'b1;
            count = 1'b1;
            if (round_cnt == 3'd7) next_state = OUT_LATCH; // go latch next
        end

        //latch catches result, DONE signals completion
        OUT_LATCH: begin
            busy = 1'b1;
            output_sig = 1'b1; // Output_reg captures {Rq,Lq}
            next_state = OUT_DONE; // delay done one cycle
        end

        OUT_DONE: begin
            busy = 1'b1;
            done = 1'b1;
            next_state = WAIT;
        end

        //start has to be lo to accept new rounds
        WAIT: begin
            busy = 1'b1;
            if (!start) next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

endmodule
