module mod7177S35 ( clk, Reset, In, Out );

    localparam signed  NTRU_Q    = 'd7177;
    localparam signed  NTRU_QH   = 'd3588;

    input                         clk;
    input                         Reset;
    input signed        [34:0]    In;
    output reg signed   [12:0]    Out;

    wire                [11:0]    intP0; // 0 ~ 4095
    wire                [12:0]    intP1; // 0 ~ 6055 
    wire                [11:0]    intP2; // 0 ~ 3710
    wire                [12:0]    intP3; // 0 ~ 7002
    wire                [11:0]    intN0; // 0 ~ 3402
    wire                [12:0]    intN1; // 0 ~ 7175

    wire                [13:0]    intP01;
    wire                [13:0]    intP01q;
    reg signed          [12:0]    regP01;
    wire                [13:0]    intP23;
    wire                [13:0]    intP23q;
    reg signed          [12:0]    regP23;
    wire                [13:0]    intN01;
    wire                [13:0]    intN01q;
    reg signed          [12:0]    regN01; 
    
    reg signed          [14:0]    regD;
    wire                [ 1:0]    intD_f;
    reg signed          [13:0]    intDq;

    mod7177Svec35 m7177Sv0 ( .z_in(In),
                             .p0(intP0), .p1(intP1), .p2(intP2), .p3(intP3),
                             .n0(intN0), .n1(intN1) );

    assign intP01   = { 2'b0, intP0 } + { 1'b0, intP1 }; // 0 ~ 10150 <= 10765 = 7177 + 3588
    assign intP01q  = (intP01 > NTRU_QH) ? -NTRU_Q : 0;
    assign intP23   = { 2'b0, intP2 } + { 1'b0, intP3 }; // 0 ~ 10712
    assign intP23q  = (intP23 > NTRU_QH) ? -NTRU_Q : 0;
    assign intN01   = { 2'b0, intN0 } + { 1'b0, intN1 }; // 0 ~ 10577
    assign intN01q  = (intN01 > NTRU_QH) ? -NTRU_Q : 0;

    always @ ( posedge clk ) begin
        if(Reset) begin
            regP01 <= 13'sd0;
            regP23 <= 13'sd0;
            regN01 <= 13'sd0;
        end else begin
            regP01 <= intP01 + intP01q; // -3588 ~ 3588
            regP23 <= intP23 + intP23q; // -3588 ~ 3588
            regN01 <= intN01 + intN01q; // -3588 ~ 3588
        end
    end

    always @ ( posedge clk ) begin
        if(Reset) begin
            regD <= 15'sd0;
        end else begin
            regD <= regP01 + regP23 - regN01;
        end
    end

    assign intD_f[0] = (regD >  NTRU_QH);
    assign intD_f[1] = (regD < -NTRU_QH);

    // Diligent Reduction
    always @ (*) begin
        casez(intD_f)
            2'b10:    intDq =  NTRU_Q;
            2'b01:    intDq = -NTRU_Q;
            default:  intDq = 'sd0;
        endcase
    end
    // Lazy Reduction
    //always @ (*) begin
    //    case(regD[14:13])
    //        2'b01: intDq = -NTRU_Q;
    //        2'b10: intDq =  NTRU_Q;
    //    endcase
    //end

    always @ ( posedge clk ) begin
        if(Reset) begin
            Out <= 13'sd0;
        end else begin
            Out <= regD + intDq;
        end
    end
    
endmodule

