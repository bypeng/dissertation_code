module mod4621S33 ( clk, Reset, In, Out );

    localparam signed  NTRU_Q    = 'd4621;
    localparam signed  NTRU_QH   = 'd2310;

    input                         clk;
    input                         Reset;
    input signed        [32:0]    In;
    output reg signed   [12:0]    Out;

    wire                [11:0]    intP0; // 0 ~ 4095
    wire                [11:0]    intP1; // 0 ~ 2046
    wire                [11:0]    intP2; // 0 ~ 3798
    wire                [11:0]    intP3; // 0 ~ 2685
    wire                [11:0]    intN0; // 0 ~ 2357
    wire                [12:0]    intN1; // 0 ~ 4158

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

    mod4621Svec33 m4621Sv0 ( .z_in(In),
                             .p0(intP0), .p1(intP1), .p2(intP2), .p3(intP3),
                             .n0(intN0), .n1(intN1) );

    assign intP01   = { 2'b0, intP0 } + { 2'b0, intP1 }; // 0 ~ 6141 <= 6931 = 4621 + 2310
    assign intP01q  = (intP01 > NTRU_QH) ? -NTRU_Q : 0;
    assign intP23   = { 2'b0, intP2 } + { 2'b0, intP3 }; // 0 ~ 6483
    assign intP23q  = (intP23 > NTRU_QH) ? -NTRU_Q : 0;
    assign intN01   = { 2'b0, intN0 } + { 1'b0, intN1 }; // 0 ~ 6515
    assign intN01q  = (intN01 > NTRU_QH) ? -NTRU_Q : 0;

    always @ ( posedge clk ) begin
        if(Reset) begin
            regP01 <= 13'sd0;
            regP23 <= 13'sd0;
            regN01 <= 13'sd0;
        end else begin
            regP01 <= intP01 + intP01q; // -2310 ~ 2310
            regP23 <= intP23 + intP23q; // -2310 ~ 2310
            regN01 <= intN01 + intN01q; // -2310 ~ 2310
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

