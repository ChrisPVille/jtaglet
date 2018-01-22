/* debug_control.v
 *
 * Example Debug Controller for a simple CPU using the JTAGlet interface
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

module debug_control(
    input jtag_tck,
    input jtag_tms,
    input jtag_tdi,
    input jtag_trst,
    output jtag_tdo,

    input sys_rstn, //System reset. Should NOT be externally tied to our cpu_resetn_cpu output

    input cpu_clk,

    output reg[31:0] cpu_imem_addr,
    output reg[31:0] cpu_debug_to_imem_data,
    input[31:0] cpu_imem_to_debug_data,
    input cpu_imem_to_debug_data_ready,
    output reg cpu_imem_ce,
    output reg cpu_imem_we,

    output reg[31:0] cpu_dmem_addr,
    output reg[31:0] cpu_debug_to_dmem_data,
    input[31:0] cpu_dmem_to_debug_data,
    input cpu_dmem_to_debug_data_ready,
    output reg cpu_dmem_ce,
    output reg cpu_dmem_we,

    output reg cpu_halt_cpu,
    output cpu_resetn_cpu
    );

    //Signals from the JTAG TAP to the synchronizer
    wire jtag_userOp_ready;

    //Resulting signal in the CPU domain
    wire cpu_userOp_ready;

    //Requested operation/data from the TAP in the JTAG domain
    wire[7:0] jtag_userOp;
    wire[31:0] jtag_userData;

    reg[31:0] cpu_userData;

    //The Jtaglet JTAG TAP
    jtaglet #(.ID_PARTVER(4'h1), .ID_PARTNUM(16'hBEEF), .ID_MANF(11'h035)) jtag_if
        (.tck(jtag_tck), .tms(jtag_tms), .tdo(jtag_tdo), .tdi(jtag_tdi), .trst(jtag_trst),
         .userData_out(jtag_userData), .userData_in(cpu_userData), .userOp(jtag_userOp),
         .userOp_ready(jtag_userOp_ready));

    //Synchronizer to take the userOp ready signal into the CPU clock domain
    ff_sync #(.WIDTH(1)) userOpReady_toCPUDomain
        (.clk(cpu_clk), .rst_p(~sys_rstn), .in_async(jtag_userOp_ready), .out(cpu_userOp_ready));

    //Stateless debug operations (which ignore debug register contents)
    localparam DEBUGOP_NOOP_OP      = 8'h00;
    localparam DEBUGOP_CPUHALT_OP   = 8'h01;
    localparam DEBUGOP_CPURESUME_OP = 8'h02;
    localparam DEBUGOP_CPURESET_OP  = 8'h03;

    //Debug operations (use previously stored data to carry out an operation)
    localparam DEBUGOP_READIMEM_OP  = 8'h04;
    localparam DEBUGOP_WRITEIMEM_OP = 8'h05;
    localparam DEBUGOP_READDMEM_OP  = 8'h06;
    localparam DEBUGOP_WRITEDMEM_OP = 8'h07;

    //Load/store debug operations (have no side-effects apart from
    //loading/storing the appropriate debug register)
    localparam DEBUGOP_IADDR_REG     = 8'h80;
    localparam DEBUGOP_IDATA_REG     = 8'h81;
    localparam DEBUGOP_DADDR_REG     = 8'h82;
    localparam DEBUGOP_DDATA_REG     = 8'h83;
    localparam DEBUGOP_CPUFLAGS_REG  = 8'h84;

    reg cpu_userOp_ready_last;
    wire execUserOp = ~cpu_userOp_ready_last & cpu_userOp_ready;

    always @(posedge cpu_clk or negedge sys_rstn) begin
        if(~sys_rstn) cpu_userOp_ready_last <= 0;
        else cpu_userOp_ready_last <= cpu_userOp_ready;
    end

    always @(posedge cpu_clk or negedge sys_rstn) begin
        if(~sys_rstn) begin
            cpu_imem_we <= 0;
            cpu_imem_ce <= 0;
        end else begin
            cpu_imem_we <= 0;
            cpu_imem_ce <= 0;
            if(execUserOp) case(jtag_userOp)
                DEBUGOP_READIMEM_OP: cpu_imem_ce <= 1;
                DEBUGOP_WRITEIMEM_OP: begin
                    cpu_imem_we <= 1;
                    cpu_imem_ce <= 1;
                end
            endcase
        end
    end

    always @(posedge cpu_clk or negedge sys_rstn) begin
        if(~sys_rstn) begin
            cpu_dmem_we <= 0;
            cpu_dmem_ce <= 0;
        end else begin
            cpu_dmem_we <= 0;
            cpu_dmem_ce <= 0;
            if(execUserOp) case(jtag_userOp)
                DEBUGOP_READDMEM_OP: cpu_dmem_ce <= 1;
                DEBUGOP_WRITEDMEM_OP: begin
                    cpu_dmem_we <= 1;
                    cpu_dmem_ce <= 1;
                end
            endcase
        end
    end

    always @(posedge cpu_clk) begin
        if(execUserOp) case(jtag_userOp)
            DEBUGOP_IADDR_REG: cpu_imem_addr <= jtag_userData;
        endcase
    end

    always @(posedge cpu_clk) begin
        if(execUserOp) case(jtag_userOp)
            DEBUGOP_IDATA_REG: cpu_debug_to_imem_data <= jtag_userData;
        endcase
    end

    always @(posedge cpu_clk) begin
        if(execUserOp) case(jtag_userOp)
            DEBUGOP_DADDR_REG: cpu_dmem_addr <= jtag_userData;
        endcase
    end

    always @(posedge cpu_clk) begin
        if(execUserOp) case(jtag_userOp)
            DEBUGOP_DDATA_REG: cpu_debug_to_dmem_data <= jtag_userData;
        endcase
    end

    always @(posedge cpu_clk or negedge sys_rstn) begin
        if(~sys_rstn) begin
            cpu_userData <= 0;
        end else begin
            if(cpu_imem_to_debug_data_ready) cpu_userData <= cpu_imem_to_debug_data;
            else if(cpu_dmem_to_debug_data_ready) cpu_userData <= cpu_dmem_to_debug_data;
        end
    end

    //Reset Stretcher
    reg requestReset;
    reg[9:0] resetStretch;
    assign cpu_resetn_cpu = ~(|resetStretch);
    always @(posedge cpu_clk or negedge sys_rstn) begin
        if(~sys_rstn) resetStretch <= 10'b0;
        else if(requestReset) resetStretch <= {10{1'b1}};
        else if(resetStretch != 0) resetStretch <= resetStretch - 1;
    end

    always @(posedge cpu_clk or negedge sys_rstn) begin
        if(~sys_rstn) begin
            cpu_halt_cpu <= 0;
            requestReset <= 0;
        end else begin
            requestReset <= 0;
            if(execUserOp) case(jtag_userOp)
                DEBUGOP_CPUHALT_OP: cpu_halt_cpu <= 1;
                DEBUGOP_CPURESUME_OP: cpu_halt_cpu <= 0;
                DEBUGOP_CPURESET_OP: begin
                    cpu_halt_cpu <= 0;
                    requestReset <= 1;
                end
            endcase
        end
    end

endmodule
