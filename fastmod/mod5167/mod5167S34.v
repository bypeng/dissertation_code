module mod5167S34 ( clk, Reset, In, Out );

    localparam signed  NTRU_Q    = 'd5167;
    localparam signed  NTRU_QH   = 'd2583;

    input                         clk;
    input                         Reset;
    input signed        [33:0]    In;
    output reg signed   [12:0]    Out;

    wire                [11:0]    intP0; // 0 ~ 4095
    wire                [11:0]    intP1; // 0 ~ 3652
    wire                [11:0]    intN0; // 0 ~ 2079
    wire                [12:0]    intN1; // 0 ~ 4888
    wire                [11:0]    intN2; // 0 ~ 3346
    wire                [12:0]    intN3; // 0 ~ 4284

    wire                [13:0]    intP01;
    wire                [13:0]    intP01q;
    reg signed          [12:0]    regP01;
    wire                [13:0]    intN01;
    wire                [13:0]    intN01q;
    reg signed          [12:0]    regN01; 
    wire                [13:0]    intN23;
    wire                [13:0]    intN23q;
    reg signed          [12:0]    regN23;
    
    reg signed          [14:0]    regD;
    wire                [ 1:0]    intD_f;
    reg signed          [13:0]    intDq;

    mod5167Svec34 m5167Sv0 ( .z_in(In),
                             .p0(intP0), .p1(intP1),
                             .n0(intN0), .n1(intN1), .n2(intN2), .n3(intN3) );

    assign intP01   = { 2'b0, intP0 } + { 2'b0, intP1 }; // 0 ~ 7747 <= 7750 = 5167 + 2583
    assign intP01q  = (intP01 > NTRU_QH) ? -NTRU_Q : 0;
    assign intN01   = { 2'b0, intN0 } + { 1'b0, intN1 }; // 0 ~ 6967
    assign intN01q  = (intN01 > NTRU_QH) ? -NTRU_Q : 0;
    assign intN23   = { 2'b0, intN2 } + { 1'b0, intN3 }; // 0 ~ 7630
    assign intN23q  = (intN23 > NTRU_QH) ? -NTRU_Q : 0;

    always @ ( posedge clk ) begin
        if(Reset) begin
            regP01 <= 13'sd0;
            regN01 <= 13'sd0;
            regN23 <= 13'sd0;
        end else begin
            regP01 <= intP01 + intP01q; // -2583 ~ 2583
            regN01 <= intN01 + intN01q; // -2583 ~ 2583
            regN23 <= intN23 + intN23q; // -2583 ~ 2583
        end
    end

    always @ ( posedge clk ) begin
        if(Reset) begin
            regD <= 15'sd0;
        end else begin
            regD <= regP01 - regN01 - regN23;
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

