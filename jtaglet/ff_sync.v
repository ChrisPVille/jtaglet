//Copyright 2017 Christopher Parish
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.

module ff_sync #(parameter WIDTH=1)(
    input clk,
    input rst_p,
    input[WIDTH-1:0] in_async,
    output reg[WIDTH-1:0] out);
    
    (* ASYNC_REG = "TRUE" *) reg[WIDTH-1:0] sync_reg;
    always @(posedge clk, posedge rst_p) begin
        if(rst_p) begin
            sync_reg <= 0;
            out <= 0;
        end else begin
            {out, sync_reg} <= {sync_reg, in_async};
        end
    end
    
endmodule
