/* jtag_reg.v
 *
 * Generic JTAG Data Register
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

module jtag_reg #(
        parameter IR_LEN = 4,
        parameter DR_LEN = 1,
        parameter IR_OPCODE = 4'b0
        ) (
        input tck,
        input trst,
        input tdi,
        output tdo,
        input state_tlr,
        input state_capturedr,
        input state_shiftdr,
        input state_updatedr,
        input[IR_LEN-1:0] ir_reg,
        input[DR_LEN-1:0] dr_dataIn,
        output reg[DR_LEN-1:0] dr_dataOut,
        output reg dr_dataOutReady
    );

    reg[DR_LEN-1:0] dr_reg;

    assign tdo = dr_reg[0];

    always @(posedge tck or negedge trst) begin
        if(~trst) begin
            dr_reg <= 0;
            dr_dataOut <= 0;
            dr_dataOutReady <= 0;
        end else begin
            dr_dataOutReady <= 0;
            if(state_tlr) dr_reg <= dr_dataIn;
            if(ir_reg == IR_OPCODE) begin
                if(state_capturedr) dr_reg <= dr_dataIn;
                else if(state_shiftdr) begin
                    if(DR_LEN == 1) dr_reg <= tdi;
                    else dr_reg <= {tdi, dr_reg[DR_LEN-1:1]};
                end else if(state_updatedr) begin
                    dr_dataOut <= dr_reg;
                    dr_dataOutReady <= 1;
                end
            end
        end
    end
endmodule
