`timescale 1ns / 1ps

module spi_master_slave_top #(
    parameter logic       CPHA    = 1'b0,
    parameter logic       CPOL    = 1'b0,
    parameter logic [3:0] CLK_DIV = 4'd10
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] tx_data,
    input  logic [6:0] addr,
    input  logic       mode,
    output logic       sclk,
    output logic       mosi,
    output logic       miso,
    output logic       ss,
    output logic       master_done,
    output logic       master_busy,
    output logic [7:0] master_rx_data,
    output logic       slave_done,
    output logic       slave_busy,
    output logic [7:0] slave_rx_data,
    output logic [6:0] slave_addr,
    output logic       slave_mode,
    output logic [7:0] mem_data_dbg
);

    logic [6:0] mem_addr;
    logic       mem_we;
    logic [7:0] mem_wdata;
    logic [7:0] mem_rdata;

    spi_master #(
        .CPHA    (CPHA),
        .CPOL    (CPOL),
        .CLK_DIV (CLK_DIV)
    ) u_master (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .tx_data (tx_data),
        .addr    (addr),
        .mode    (mode),
        .sclk    (sclk),
        .mosi    (mosi),
        .miso    (miso),
        .ss      (ss),
        .done    (master_done),
        .busy    (master_busy),
        .rx_data (master_rx_data)
    );

    spi_slave #(
        .CPHA (CPHA),
        .CPOL (CPOL)
    ) u_slave (
        .clk         (clk),
        .rst         (rst),
        .sclk        (sclk),
        .mosi        (mosi),
        .ss          (ss),
        .mem_rdata   (mem_rdata),
        .mem_addr    (mem_addr),
        .mem_we      (mem_we),
        .mem_wdata   (mem_wdata),
        .miso        (miso),
        .busy        (slave_busy),
        .done        (slave_done),
        .rx_data     (slave_rx_data),
        .active_addr (slave_addr),
        .active_mode (slave_mode)
    );

    spi_mem u_mem (
        .clk     (clk),
        .rst     (rst),
        .we      (mem_we),
        .wr_addr (mem_addr),
        .wr_data (mem_wdata),
        .rd_addr (mem_addr),
        .rd_data (mem_rdata)
    );

    assign mem_data_dbg = mem_rdata;

endmodule
