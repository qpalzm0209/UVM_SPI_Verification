interface spi_if(input logic clk);
    logic       rst;
    logic       start;
    logic [7:0] tx_data;
    logic [6:0] addr;
    logic       mode;

    logic       sclk;
    logic       mosi;
    logic       miso;
    logic       ss;
    logic       master_done;
    logic       master_busy;
    logic [7:0] master_rx_data;
    logic       slave_done;
    logic       slave_busy;
    logic [7:0] slave_rx_data;
    logic [6:0] slave_addr;
    logic       slave_mode;
    logic [7:0] mem_data_dbg;

    clocking drv_cb @(posedge clk);
        output start;
        output tx_data;
        output addr;
        output mode;

        input rst;
        input sclk;
        input mosi;
        input miso;
        input ss;
        input master_done;
        input master_busy;
        input master_rx_data;
    endclocking

    clocking mon_cb @(posedge clk);
        input rst;
        input start;
        input tx_data;
        input addr;
        input mode;
        input sclk;
        input mosi;
        input miso;
        input ss;
        input master_done;
        input master_busy;
        input master_rx_data;
    endclocking
endinterface
