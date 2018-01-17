/* jtag_state_machine.v
 *
 * JTAG TAP State Machine
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

module jtag_state_machine(
        input tck,
        input tms,
        input trst,

        output state_tlr,
        output state_capturedr,
        output state_captureir,
        output state_shiftdr,
        output state_shiftir,
        output state_updatedr,
        output state_updateir

    );

    localparam TEST_LOGIC_RESET = 4'h0;
    localparam RUN_TEST_IDLE    = 4'h1;
    localparam SELECT_DR        = 4'h2;
    localparam CAPTURE_DR       = 4'h3;
    localparam SHIFT_DR         = 4'h4;
    localparam EXIT1_DR         = 4'h5;
    localparam PAUSE_DR         = 4'h6;
    localparam EXIT2_DR         = 4'h7;
    localparam UPDATE_DR        = 4'h8;
    localparam SELECT_IR        = 4'h9;
    localparam CAPTURE_IR       = 4'hA;
    localparam SHIFT_IR         = 4'hB;
    localparam EXIT1_IR         = 4'hC;
    localparam PAUSE_IR         = 4'hD;
    localparam EXIT2_IR         = 4'hE;
    localparam UPDATE_IR        = 4'hF;

    reg[3:0] state;

    always @(posedge tck or negedge trst) begin
        if(~trst) begin
            state <= TEST_LOGIC_RESET;
        end else begin
            case(state)
                TEST_LOGIC_RESET: state <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
                RUN_TEST_IDLE:    state <= tms ? SELECT_DR : RUN_TEST_IDLE;
                SELECT_DR :       state <= tms ? SELECT_IR : CAPTURE_DR;
                CAPTURE_DR :      state <= tms ? EXIT1_DR : SHIFT_DR;
                SHIFT_DR:         state <= tms ? EXIT1_DR : SHIFT_DR;
                EXIT1_DR:         state <= tms ? UPDATE_DR : PAUSE_DR;
                PAUSE_DR:         state <= tms ? EXIT2_DR : PAUSE_DR;
                EXIT2_DR:         state <= tms ? UPDATE_DR : SHIFT_DR;
                UPDATE_DR:        state <= tms ? SELECT_DR : RUN_TEST_IDLE;
                SELECT_IR:        state <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;
                CAPTURE_IR:       state <= tms ? EXIT1_IR : SHIFT_IR;
                SHIFT_IR :        state <= tms ? EXIT1_IR : SHIFT_IR;
                EXIT1_IR:         state <= tms ? UPDATE_IR : PAUSE_IR;
                PAUSE_IR:         state <= tms ? EXIT2_IR : PAUSE_IR;
                EXIT2_IR:         state <= tms ? UPDATE_IR : SHIFT_IR;
                UPDATE_IR:        state <= tms ? SELECT_DR : RUN_TEST_IDLE;
            endcase
        end
    end

    //I was going to use a function, but Vivado pooped itself when I tried. Typical...
    assign state_tlr = (state == TEST_LOGIC_RESET);
    assign state_capturedr = (state == CAPTURE_DR);
    assign state_captureir = (state == CAPTURE_IR);
    assign state_shiftdr = (state == SHIFT_DR);
    assign state_shiftir = (state == SHIFT_IR);
    assign state_updatedr = (state == UPDATE_DR);
    assign state_updateir = (state == UPDATE_IR);

endmodule
