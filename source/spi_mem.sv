`timescale 1ns / 1ps

module spi_mem(
    input  logic       clk,
    input  logic       rst,
    input  logic       we,
    input  logic [6:0] wr_addr,
    input  logic [7:0] wr_data,
    input  logic [6:0] rd_addr,
    output logic [7:0] rd_data
);

    integer idx;
    logic [7:0] mem [0:127];

    assign rd_data = mem[rd_addr];

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            for (idx = 0; idx < 128; idx = idx + 1) begin
                mem[idx] <= 8'h00;
            end
        end else if (we) begin
            mem[wr_addr] <= wr_data;
        end
    end

endmodule
