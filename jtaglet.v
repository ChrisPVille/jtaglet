/* jtaglet.v
 *
 * Top module for the JTAGlet JTAG TAP project
 *
 *------------------------------------------------------------------------------
 *
 * Copyright 2018 Christopher Parish
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module jtaglet #(
    parameter IR_LEN = 4,
    parameter ID_PARTVER = 4'h0,
    parameter ID_PARTNUM = 16'h0000,
    parameter ID_MANF = 11'h000,
    parameter USERDATA_LEN = 32,
    parameter USEROP_LEN = 8
    )(
    input tck,
    input tms,
    input tdi,
    output reg tdo,
    input trst,

    input[USERDATA_LEN-1:0] userData_in,
    output[USERDATA_LEN-1:0] userData_out,
    output[USEROP_LEN-1:0] userOp,
    output userOp_ready
    );

    localparam USERDATA_OP = 4'b1000;
    localparam USEROP_OP = 4'b1001;
    localparam IDCODE_OP = {{(IR_LEN-1){1'b1}},1'b0}; //e.g. b1110
    localparam BYPASS_OP = {IR_LEN{1'b1}};// e.g. b1111 (required bit pattern per spec)

    wire[31:0] idcode = {ID_PARTVER, ID_PARTNUM, ID_MANF, 1'b1};

    wire state_tlr, state_capturedr, state_captureir, state_shiftdr, state_shiftir,
        state_updatedr, state_updateir;

    jtag_state_machine jsm(.tck(tck), .tms(tms), .trst(trst), .state_tlr(state_tlr),
        .state_capturedr(state_capturedr), .state_captureir(state_captureir),
        .state_shiftdr(state_shiftdr), .state_shiftir(state_shiftir),
        .state_updatedr(state_updatedr), .state_updateir(state_updateir));

    reg[IR_LEN-1:0] ir_reg;

    //USERDATA - DR becomes a USERDATA_LEN bit user data register passed out of the module
    wire userData_tdo;
    jtag_reg #(.IR_LEN(IR_LEN), .DR_LEN(USERDATA_LEN), .IR_OPCODE(USERDATA_OP)) userData_reg
        (.tck(tck), .trst(trst), .tdi(tdi), .tdo(userData_tdo), .state_tlr(state_tlr),
         .state_capturedr(state_capturedr), .state_shiftdr(state_shiftdr),
         .state_updatedr(state_updatedr), .ir_reg(ir_reg), .dr_dataOut(userData_out),
         .dr_dataIn(userData_in), .dr_dataOutReady());

    //USEROPCODE - DR becomes an 8 bit operation select/initiate register passed out of the module
    wire userOp_tdo;
    jtag_reg #(.IR_LEN(IR_LEN), .DR_LEN(USEROP_LEN), .IR_OPCODE(USEROP_OP)) userOp_reg
        (.tck(tck), .trst(trst), .tdi(tdi), .tdo(userOp_tdo), .state_tlr(state_tlr),
         .state_capturedr(state_capturedr), .state_shiftdr(state_shiftdr),
         .state_updatedr(state_updatedr), .ir_reg(ir_reg), .dr_dataOut(userOp),
         .dr_dataIn(8'b0), .dr_dataOutReady(userOp_ready));

    //IDCODE - DR is pre-loaded with the 32 bit identification code of this part
    wire idcode_tdo;
    jtag_reg #(.IR_LEN(IR_LEN), .DR_LEN(32), .IR_OPCODE(IDCODE_OP)) idcode_reg
        (.tck(tck), .trst(trst), .tdi(tdi), .tdo(idcode_tdo), .state_tlr(state_tlr),
         .state_capturedr(state_capturedr), .state_shiftdr(state_shiftdr),
         .state_updatedr(1'b0), .ir_reg(ir_reg), .dr_dataOut(),
         .dr_dataIn(idcode), .dr_dataOutReady());

    //BYPASS - DR becomes a 1 bit wide register, suitable for bypassing this part
    wire bypass_tdo;
    jtag_reg #(.IR_LEN(IR_LEN), .DR_LEN(1), .IR_OPCODE(BYPASS_OP)) bypass_reg
         (.tck(tck), .trst(trst), .tdi(tdi), .tdo(bypass_tdo), .state_tlr(state_tlr),
          .state_capturedr(state_capturedr), .state_shiftdr(state_shiftdr),
          .state_updatedr(1'b0), .ir_reg(ir_reg), .dr_dataOut(),
          .dr_dataIn(1'b0), .dr_dataOutReady());

    //Instruction Register
    wire ir_tdo;
    assign ir_tdo = ir_reg[0];
    always @(posedge tck or negedge trst) begin
        if(~trst) begin
            ir_reg <= IDCODE_OP;
        end else if(state_tlr) begin
            ir_reg <= IDCODE_OP;
        end else if(state_captureir) begin
            //We need to load the BYPASS reg with seq ending in 01.
            ir_reg <= {{(IR_LEN-1){1'b0}},1'b1}; //e.g. b0001
        end else if(state_shiftir) begin
            ir_reg <= {tdi, ir_reg[IR_LEN-1:1]};
        end
    end

    //IR selects the appropriate DR
    reg tdo_pre;
    always @(*) begin
        tdo_pre = 0;
        if(state_shiftdr) begin
            case(ir_reg)
                IDCODE_OP:      tdo_pre = idcode_tdo;
                BYPASS_OP:      tdo_pre = bypass_tdo;
                USERDATA_OP:    tdo_pre = userData_tdo;
                USEROP_OP:      tdo_pre = userOp_tdo;
                default:        tdo_pre = bypass_tdo;
            endcase
        end else if(state_shiftir) begin
            tdo_pre = ir_tdo;
        end
    end

    //TDO updates on the negative edge according to the spec
    always @(negedge tck)
    begin
        tdo <= tdo_pre;
    end

endmodule
