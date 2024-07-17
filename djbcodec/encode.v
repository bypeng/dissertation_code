/*******************************************************************
 * NTRU Prime General R/q[x] / x^p - x - 1 Encoder
 *
 * Author: Bo-Yuan Peng       bypeng@crypto.tw
 *
 * Note:
 * Use only with the corresponding parameter modules.
 *
 * Version Info:
 *    Nov.19,2019: 0.1.0 Design ready.
 *    Aug.17,2020: 0.1.1 Bug fix for edge cases. 
 *
 *******************************************************************/

`include "params.v"

module encode_rp ( clk, start, done, state_l, state_e, state_s,
    rp_rd_addr, rp_rd_data,
    cd_wr_addr, cd_wr_data, cd_wr_en,

    state_max,

    param_state_ct,
    param_r_max, param_m0, //param_1st_round,
    param_outs1, param_outsl
) ; 

    input                           clk;
    input                           start;
    output                          done;
    output      [4:0]               state_l;
    output      [4:0]               state_e;
    output      [4:0]               state_s;

    output      [`RP_DEPTH-1:0]     rp_rd_addr;
    input       [`RP_D_SIZE-1:0]    rp_rd_data;
    output reg  [`OUT_DEPTH-1:0]    cd_wr_addr;
    output reg  [`OUT_D_SIZE-1:0]   cd_wr_data;
    output reg                      cd_wr_en;

    input       [4:0]               state_max;

    input       [`RP_DEPTH-1:0]     param_state_ct;
    input       [`RP_DEPTH-1:0]     param_r_max;
    input       [`RP_D_SIZE-1:0]    param_m0;
    //input                           param_1st_round;
    input       [1:0]               param_outs1;
    input       [2:0]               param_outsl;

    reg                             rb_wr_en;
    wire        [`RP_DEPTH-2:0]     rb_wr_addr;
    wire        [`RP_D_SIZE-1:0]    rb_wr_data;
    wire        [`RP_D_SIZE-1:0]    rb_wr_rd_data;
    wire        [`RP_DEPTH-2:0]     rb_rd_addr;
    wire        [`RP_D_SIZE-1:0]    rb_rd_data;
    wire        [`RP_D_SIZE-1:0]    rb_rd_data_out;
    reg                             rb_wr_through;

    reg         [4:0]               state[4:0];
    //wire        [4:0]               state_s1;
    reg         [4:0]               state_next;
    reg         [`RP_DEPTH-1:0]     state_ct[4:0];
    reg         [`RP_DEPTH-1:0]     state_ctF[4:0];
    wire        [`RP_DEPTH-1:0]     sc_l;
    wire        [`RP_DEPTH-1:0]     sc_lF;
    wire        [`RP_DEPTH-1:0]     sc_l1F;
    wire        [`RP_DEPTH-1:0]     sc_eF;
    wire        [`RP_DEPTH-1:0]     sc_s;
    wire        [`RP_DEPTH-1:0]     sc_sF;

    wire        [`RP_DEPTH-1:0]     r_rd_addr;
    wire                            r_rd_addr_max;
    reg         [`RP_DEPTH-1:0]     r_max;
    wire        [`RP_DEPTH-1:0]     r_max_minus;
    reg         [`RP_DEPTH-1:0]     r_max_1;
    reg         [`RP_DEPTH-1:0]     r_max_2;

    wire        [`RP_DEPTH-2:0]     out_r_max_eval;
    reg         [`RP_DEPTH-2:0]     out_r_max[1:0];
    wire        [`RP_DEPTH-2:0]     out_r_max_e;

    reg         [2:0]               odd_r;
    reg         [1:0]               outs1[1:0];
    reg         [2:0]               outsl[1:0];

    wire                            last_r;
    wire                            reserve_r;

    wire        [`RP_D_SIZE-1:0]    r_data;
    wire        [`RP_D_SIZE-1:0]    r1;
    reg         [`RP_D_SIZE-1:0]    r0;
    
    wire        [`RP_D_SIZE2-1:0]   r1m0_r0;

    reg         [`RP_D_SIZE-1:0]    r_next;

    reg         [7:0]               o0;
    reg         [7:0]               o1;
    reg         [7:0]               o2;
    reg         [7:0]               o3;

    reg                             cd_wr_do;

    bram_p # ( .D_SIZE(`RP_D_SIZE), .Q_DEPTH(`RP_DEPTH-1) ) r_buffer (
        .clk(clk),
        .wr_en(rb_wr_en),
        .wr_addr(rb_wr_addr),
        .wr_din(rb_wr_data),
        .wr_dout(rb_wr_rd_data),
        .rd_addr(rb_rd_addr),
        .rd_dout(rb_rd_data_out)
    ) ;

    always @(posedge clk) begin
    	  if(rb_wr_en == 1'b1 && rb_wr_addr == rb_rd_addr ) begin
    		    rb_wr_through <= 1'b1;
    	  end else begin
    		    rb_wr_through <= 1'b0;
    	  end
    end
    
    assign rb_rd_data = rb_wr_through ? rb_wr_rd_data : rb_rd_data_out;
    //assign rb_rd_data = rb_rd_data_out;

    assign r_rd_addr_max = (sc_lF >= r_max);

    always @ ( posedge clk ) begin
        if(start) begin
            state[0] <= 5'd0;
            state[1] <= 5'd0;
            state[2] <= 5'd0;
            state[3] <= 5'd0;
            state[4] <= 5'd0;
        end else begin
            state[0] <= state_next;
            state[1] <= state[0];
            state[2] <= state[1];
            state[3] <= state[2];
            state[4] <= state[3];
        end
    end
    assign state_l = state[0];
    assign state_e = state[2];
    assign state_s = state[3];
    //assign state_s1 = state[4];

    assign doneL = (state_l == 5'd31);
    assign done = (state_s == 5'd31);

    always @ (*) begin
        if ( state_l == 5'd0 ) begin
            state_next = 5'd1;
        end else begin
            if ( ~|sc_l ) begin
                if ( ( state_l == state_max ) || doneL ) begin
                    state_next = 5'd31;
                end else begin
                    state_next = state_l + 5'd1;
                end
            end else begin
                state_next = state_l;
            end
        end
    end

    always @ ( posedge clk ) begin
        if ( start ) begin
            state_ct[0]  <= param_state_ct + 1;
            state_ctF[0] <= -'d1 ;
        end else if ( ~|sc_l ) begin
            state_ct[0]  <= param_state_ct ;
            state_ctF[0] <= 'd0 ;
        end else begin
            state_ct[0]  <= state_ct[0]  - 'd1;
            state_ctF[0] <= state_ctF[0] + 'd1;
        end
        state_ct[1] <= state_ct[0]; state_ctF[1] <= state_ctF[0];
        state_ct[2] <= state_ct[1]; state_ctF[2] <= state_ctF[1];
        state_ct[3] <= state_ct[2]; state_ctF[3] <= state_ctF[2];
        state_ct[4] <= state_ct[3]; state_ctF[4] <= state_ctF[3];
    end
    assign sc_l   = state_ct[0];
    assign sc_lF  = state_ctF[0];
    assign sc_l1F = state_ctF[1];
    assign sc_eF  = state_ctF[2];
    assign sc_s   = state_ct[3];
    assign sc_sF  = state_ctF[3];

    assign state_1st_round = (state_l == 5'd1);

    always @ ( posedge clk ) begin
        if(start || ~|sc_l ) begin
            r_max <= param_r_max;
        end
        r_max_1 <= r_max;
        r_max_2 <= r_max_1;
    end
    assign r_max_minus  = r_max - 'd1;
    assign out_r_max_eval = r_max[`RP_DEPTH-1:1] - { { (`RP_DEPTH-1) {1'b0} }, ~r_max[0] };

    always @ ( posedge clk ) begin
        odd_r[0] <= r_max[0];
        odd_r[1] <= odd_r[0];
        odd_r[2] <= odd_r[1];

        out_r_max[0] <= out_r_max_eval;
        out_r_max[1] <= out_r_max[0];

        outs1[0] <= param_outs1;
        outsl[0] <= param_outsl;
        outs1[1] <= outs1[0];
        outsl[1] <= outsl[0];
    end
    assign out_r_max_e = out_r_max[1];

    assign r_rd_addr = r_rd_addr_max ? r_max_minus : sc_lF;
    assign rb_rd_addr = r_rd_addr;
    assign rp_rd_addr = r_rd_addr;
    assign r_data = state_1st_round ? rp_rd_data : rb_rd_data; 

    always @ ( posedge clk ) begin
        if( start ) begin
            r0 <= 'd0;
        end else begin
            if(!sc_l1F[0]) begin
                r0 <= r_data; 
            end
        end
    end

    assign r1 = r_data;

    assign r1m0_r0 = r1 * param_m0 + r0;

    assign last_r = (sc_eF[`RP_DEPTH-1:1] == out_r_max_e);
    assign reserve_r = last_r && odd_r[1];

    always @ ( posedge clk ) begin
        if ( start ) begin
            r_next <= 'd0;
        end else begin
            if ( ~sc_eF[0] ) begin
                if( reserve_r ) begin
                    r_next <= r0;
                end else begin
                    casez ( { last_r, param_outs1, param_outsl[1:0] } )
                        { 1'b0, 2'd2, 2'b?? }, { 1'b1, 2'b??, 2'd2 } : r_next <= r1m0_r0[27:16];
                        { 1'b0, 2'd1, 2'b?? }, { 1'b1, 2'b??, 2'd1 } : r_next <= r1m0_r0[21:8];
                        { 1'b0, 2'd0, 2'b?? }, { 1'b1, 2'b??, 2'd0 } : r_next <= r1m0_r0[13:0];
                        default: r_next <= r_next;
                    endcase
                end
            end
        end
    end

    always @ ( posedge clk ) begin
        if( start ) begin
            o0 <= 'd0;
            o1 <= 'd0;
            o2 <= 'd0;
            o3 <= 'd0;
        end else begin
            if(state_e == state_max) begin
                if( ~|sc_eF ) begin
                    o0 <= r1m0_r0[7:0];
                    o1 <= r1m0_r0[15:8];
                    o2 <= r1m0_r0[23:16];
                    o3 <= r1m0_r0[27:24];
                end
            end else begin
                if( ~sc_eF[0] ) begin
                    o0 <= r1m0_r0[7:0];
                    o1 <= r1m0_r0[15:8];
                end
            end
        end
    end

    always @ ( posedge clk ) begin
        if( start || sc_eF[0] || state_e == state_max || &state_e ) begin
            rb_wr_en <= 1'b0;
        end else begin
            if ( sc_eF[`RP_DEPTH-1:1] <= out_r_max_e )
                rb_wr_en <= 1'b1;
            else
                rb_wr_en <= 1'b0;
        end
    end

    assign rb_wr_addr = sc_sF[`RP_DEPTH-1:1];
    assign rb_wr_data = r_next;

    always @ (*) begin
        if ( state_e == state_max ) begin
            if( sc_eF < param_outsl ) begin
                cd_wr_do = 1'b1;
            end else begin
                cd_wr_do = 1'b0;
            end 
        end else begin
            if( (sc_eF[`RP_DEPTH-1:1] == out_r_max_e) && !reserve_r ) begin
                if( (sc_eF[0] && |param_outsl[2:1]) || (!sc_eF[0] && |param_outsl) ) begin
                    cd_wr_do = 1'b1;
                end else begin
                    cd_wr_do = 1'b0;
                end
            end else if( sc_eF[`RP_DEPTH-1:1] < out_r_max_e ) begin
                if( (sc_eF[0] && param_outs1[1]) || (!sc_eF[0] && |param_outs1) ) begin
                    cd_wr_do = 1'b1;
                end else begin
                    cd_wr_do = 1'b0;
                end 
            end else begin
                cd_wr_do = 1'b0;
            end
        end
    end

    always @ ( posedge clk ) begin
        if( start || &state_e ) begin
            cd_wr_en <= 1'b0;
            cd_wr_addr <= -'sd1;
        end else begin
            if(cd_wr_do) begin
                cd_wr_en <= 1'b1;
                cd_wr_addr <= cd_wr_addr + 'd1;
            end else begin
                cd_wr_en <= 1'b0;
                cd_wr_addr <= cd_wr_addr;
            end
        end
    end

    always @ (*) begin
        if(state_s == state_max) begin
            case(sc_sF)
                'd0: cd_wr_data = o0;
                'd1: cd_wr_data = o1; // MASK needed
                'd2: cd_wr_data = o2; // MASK needed 
                'd3: cd_wr_data = o3; // MASK needed
                default: cd_wr_data = 'd0;
            endcase
        end else begin
            if(sc_sF[0])
                cd_wr_data = o1; // MASK needed
            else
                cd_wr_data = o0; // MASK needed
        end
    end

endmodule
