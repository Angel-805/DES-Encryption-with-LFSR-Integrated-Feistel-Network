`timescale 1ns/100ps

module des_top(
    input clk, rst_n, start, 
        enc_dec, // 1=encrypt, 0=decrypt
    input  [63:0] data_in, //data to be encrypted or decrypted
    output [63:0] data_out, //data coming out after enc or dec
    output done, busy,
        valid //data_out is ready to use
);

    wire rst = ~rst_n;

    //load signals
    wire load_d; 
    wire load_k;

    //signals to advance to new round
    wire round;
    wire count;

    //latch final result at output_reg
    wire output_sig;


    wire keys_ready;
    wire [2:0] fsm_state;
    
    // exposes state instance to  testbench
    wire [2:0] state = fsm_state;

    //represent curr round from 0-7
    reg [2:0] round_cnt;

   //split data into 2 32bit halves using Input_reg
    wire [31:0] in_L, in_R;
    wire in_trigger; // pulses 1 the cycle AFTER load_d to say split is done
    Input_reg U_in (
        .clk(clk), .rst(rst), .load(load_d),
        .data_in(data_in),
        .left_out(in_L), .right_out(in_R),
        .trigger(in_trigger)
    );

    // Seed signal when Input_reg has fresh outputs
    wire seed = in_trigger;

    //mux inputs and outs to Left and right regs
    reg  [31:0] L_mux_in, R_mux_in;
    wire [31:0] L_q, R_q;
    
    //determine round vs seed cycle
    wire round_en = round & ~seed;
    wire lr_load  = seed | round_en;

    // Feistel outputs
    wire [31:0] L_out, R_out;

    // Choose inputs to L/R regs
    // seed from Input_reg on seed cycle
    //  else get from Feistel
    always @* begin
        L_mux_in = seed ? in_L : L_out;
        R_mux_in = seed ? in_R : R_out;
    end

    Left_reg  U_left  (.clk(clk), .rst(rst), .load(lr_load), .data_in(L_mux_in), .data_out(L_q));
    Right_reg U_right (.clk(clk), .rst(rst), .load(lr_load), .data_in(R_mux_in), .data_out(R_q));

    //round counter for DES
    always @(posedge clk or posedge rst) begin
        if (rst) round_cnt <= 3'd0;
        else if (seed) round_cnt <= 3'd0; // new op seeds then start at round 0
        else if (round_en) round_cnt <= round_cnt + 3'd1;
    end

    //generats keys
    //circular rotation for bits
    //XOR by shifter
    reg keys_loaded;
    reg  [2:0] keygen_idx;
    reg [47:0] keys [0:7];
    function [47:0] rol48;
        input [47:0] x;
        input [5:0]  s;    // 0..47
        reg [47:0] a, b;
    begin
        a = x << s;
        b = x >> (6'd48 - s);
        rol48 = a | b;
    end
    endfunction

    //generate 8 keys
    function [47:0] make_key;
        input [2:0] idx;
        reg   [47:0] base;
    begin
        base = 48'hA5A5_A5A5_A5A5;
        make_key = rol48(base, {3'b000, idx}) ^ (48'h0123_4567_89AB >> idx);
    end
    endfunction

    // storage instanc for testbench
    wire [47:0] storage_dout;
    reg key_store_mode; // 1=write during init, else 0
    reg [3:0]  key_addr;
    reg [47:0] key_data_in;

    //dual storage
    Rnd_key_storage #(.DEPTH(16), .ADDR_WIDTH(4)) U_storage (
        .clk(clk), .rst(rst), .mode(key_store_mode),
        .addr(key_addr), .data_in(key_data_in), .data_out(storage_dout)
    );

    //generat and store keys so we can skip WAIT
    assign keys_ready = keys_loaded;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            keys_loaded <= 1'b0;
            keygen_idx <= 3'd0;
            key_store_mode <= 1'b0; // read by default
            key_addr <= 4'd0;
            key_data_in <= 48'd0;
        end 
        
        //Generate 8 keys when we get load signal
        //8 clock cycles
        //flag to prevent repeat
        else begin
            if (!keys_loaded && load_k) begin
                key_store_mode <= 1'b1; // write
                key_addr <= {1'b0, keygen_idx}; // 0..7
                
                //internal storage
                key_data_in <= make_key(keygen_idx);
                keys[keygen_idx] <= make_key(keygen_idx);
                if (keygen_idx == 3'd7) begin
                    keys_loaded <= 1'b1;
                end
                keygen_idx <= keygen_idx + 3'd1;
            end else begin
                key_store_mode <= 1'b0; // idle/read
            end
        end
    end

    //key slection
    wire [2:0]  key_idx = enc_dec ? round_cnt : (3'd7 - round_cnt);
    wire [47:0] round_key = keys[key_idx];

    
    Feistel U_feistel (
        .left_in(L_q),
        .right_in(R_q),
        .round_key(round_key),
        .left_out(L_out),
        .right_out(R_out)
    );

   
    Output_reg U_out (
        .clk(clk), .rst(rst), .load(output_sig),
        .left_in(L_q), .right_in(R_q),
        .data_out(data_out), .valid(valid)
    );

    des_fsm U_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .enc_dec(enc_dec),
        .round_cnt(round_cnt),
        .keys_ready(keys_ready),
        .done(done),
        .busy(busy),
        .load_d(load_d),
        .load_k(load_k),
        .round(round),
        .count(count),
        .output_sig(output_sig),
        .state(fsm_state)
    );

    always @(posedge clk) begin
        if (round_en) begin
            $display("Round %0d: L=%h R=%h Key=%h (idx=%0d)",
                     round_cnt, L_q, R_q, round_key, key_idx);
        end
        if (output_sig) begin
            $display("OUT: Lq=%h Rq=%h -> data_out=%h", L_q, R_q, data_out);
        end
    end

endmodule
