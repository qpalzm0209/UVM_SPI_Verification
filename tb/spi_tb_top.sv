`timescale 1ns / 1ps

module spi_tb_top;
    import uvm_pkg::*;
    import spi_uvm_pkg::*;

    logic clk;
    spi_if tb_if(clk);

    spi_master_slave_top dut (
        .clk            (clk),
        .rst            (tb_if.rst),
        .start          (tb_if.start),
        .tx_data        (tb_if.tx_data),
        .addr           (tb_if.addr),
        .mode           (tb_if.mode),
        .sclk           (tb_if.sclk),
        .mosi           (tb_if.mosi),
        .miso           (tb_if.miso),
        .ss             (tb_if.ss),
        .master_done    (tb_if.master_done),
        .master_busy    (tb_if.master_busy),
        .master_rx_data (tb_if.master_rx_data),
        .slave_done     (tb_if.slave_done),
        .slave_busy     (tb_if.slave_busy),
        .slave_rx_data  (tb_if.slave_rx_data),
        .slave_addr     (tb_if.slave_addr),
        .slave_mode     (tb_if.slave_mode),
        .mem_data_dbg   (tb_if.mem_data_dbg)
    );

    always #5 clk = ~clk;

    initial begin
        clk           = 1'b0;
        tb_if.rst     = 1'b1;
        tb_if.start   = 1'b0;
        tb_if.tx_data = 8'h00;
        tb_if.addr    = 7'h00;
        tb_if.mode    = 1'b0;

        repeat (10) @(posedge clk);
        tb_if.rst = 1'b0;
    end

    initial begin
        string wave_file;

        if ($value$plusargs("WAVE_FILE=%s", wave_file)) begin
            $dumpfile(wave_file);
            $dumpvars(0, dut);
            $dumpvars(0, clk);
        end
    end

    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "*", "vif", tb_if);
        run_test();
    end
endmodule
