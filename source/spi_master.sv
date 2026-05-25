`timescale 1ns / 1ps

module spi_master #(
    parameter logic       CPHA    = 1'b0,
    parameter logic       CPOL    = 1'b0,
    parameter logic [3:0] CLK_DIV = 4'd10
)(
    // top module side
    input  logic       clk,
    input  logic       rst,
    input  logic       start,    // btn_c
    input  logic [7:0] tx_data,  // sw[7:0]
    input  logic [6:0] addr,     // sw[14:8]
    input  logic       mode,     // sw[15]
    // slave side
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       ss,
    // condition sig
    output logic done,
    output logic busy,
    // resert data 
    output logic [7:0] rx_data
);


    // addr part define ================================================================

    logic [7:0] addr_byte;
    assign addr_byte = {addr, mode};

    // data part define ================================================================

    logic [7:0] data_byte;
    assign data_byte = tx_data;

    // state define ====================================================================

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        SET_ADDR,
        ADDR,
        WAIT,
        READ,  // mode = 0
        WRITE, // mode = 1
        STOP
    } state_t;

    state_t state;

    // timming define ===================================================================

    logic       sclk_r;
    logic       sample_edge;
    logic       launch_edge;
    logic [3:0] bit_cnt;
    logic [3:0] div_cnt;
    logic       half_tick;

    assign sclk        = sclk_r;
    assign sample_edge = (CPHA == 1'b0) ? (sclk_r == CPOL) : ~(sclk_r == CPOL);
    assign launch_edge = ~sample_edge;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            div_cnt   <= '0;
            half_tick <= 1'b0;
        end else if (state != IDLE) begin
            half_tick <= 1'b0;
            if (div_cnt == (CLK_DIV - 1'b1)) begin
                div_cnt   <= '0;
                half_tick <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end else begin
            div_cnt   <= '0;
            half_tick <= 1'b0;
        end
    end

    // register define ==================================================================

    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [7:0] addr_byte_reg;
    logic [7:0] data_byte_reg;
    logic       mode_reg;

    // fsm dfine ========================================================================

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
        // register serise
            state        <= IDLE;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            addr_byte_reg <= 0;
            data_byte_reg <= 0;
            mode_reg      <= 0;
            bit_cnt      <= 0;
        // slave side
            sclk_r <= CPOL;
            mosi   <= 1;
            ss     <= 1;
        // condition sig
            done <= 0;
            busy <= 0;
        // resert data
            rx_data <= 0;
        end else begin
            done <= 1'b0;

            case (state) 
                IDLE : begin
                    busy   <= 1'b0;
                    mosi   <= 1;
                    ss     <= 1;
                    sclk_r <= CPOL;
                    if (start) begin
                        addr_byte_reg <= addr_byte;
                        data_byte_reg <= data_byte;
                        mode_reg      <= mode;
                        tx_shift_reg <= addr_byte;
                        bit_cnt      <= 3'd7;
                        rx_shift_reg <= 8'h00;
                        busy         <= 1'b1;
                        ss           <= 1'b0;
                        state        <= SET_ADDR;
                    end
                end
                SET_ADDR : begin
                    sclk_r        <= CPOL;
                    if (!CPHA) begin
                        mosi         <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        bit_cnt      <= 4'd7;
                        state        <= ADDR;
                    end else if (half_tick) begin
                        sclk_r       <= ~sclk_r;
                        mosi         <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        bit_cnt      <= 4'd7;
                        state        <= ADDR;
                    end
                end
                ADDR : begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;
                        if (sample_edge) begin
                            if (bit_cnt == 0) begin
                                state <= WAIT;
                            end
                        end else if (launch_edge) begin
                            if (bit_cnt != 0) begin
                                mosi         <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                bit_cnt      <= bit_cnt - 1'b1;
                            end
                        end
                    end
                end
                WAIT : begin
                    if (half_tick) begin
                        sclk_r  <= ~sclk_r;
                        if (!mode_reg) begin
                            mosi         <= 1'b1;
                            rx_shift_reg <= 8'h00;
                            bit_cnt      <= 4'd8;
                            state        <= READ;
                        end else begin
                            mosi         <= data_byte_reg[7];
                            tx_shift_reg <= {data_byte_reg[6:0], 1'b0};
                            bit_cnt      <= 4'd7;
                            state        <= WRITE;
                        end
                    end
                end
                READ : begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;
                        if (sample_edge) begin
                            if (bit_cnt == 4'd1)begin
                                rx_data <= {rx_shift_reg[6:0], miso};
                                state   <= STOP;
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                                bit_cnt      <= bit_cnt - 1'b1;
                            end
                        end
                    end
                end
                WRITE : begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;
                        if (sample_edge) begin
                            if (bit_cnt == 0) begin
                                state <= STOP;
                            end
                        end else if (launch_edge) begin
                            if (bit_cnt != 0) begin
                                mosi         <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                bit_cnt      <= bit_cnt - 1'b1;
                            end
                        end
                    end
                end
                STOP : begin
                    if (half_tick) begin
                        sclk_r <= CPOL;
                        ss     <= 1'b1;
                        done   <= 1'b1;
                        busy   <= 1'b0;
                        mosi   <= 1'b1;
                        state  <= IDLE;
                    end
                end
            endcase
        end
    end


endmodule
