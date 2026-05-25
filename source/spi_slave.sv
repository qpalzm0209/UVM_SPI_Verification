`timescale 1ns / 1ps

module spi_slave #(
    parameter logic CPHA = 1'b0,
    parameter logic CPOL = 1'b0
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       sclk,
    input  logic       mosi,
    input  logic       ss,
    input  logic [7:0] mem_rdata,
    output logic [6:0] mem_addr,
    output logic       mem_we,
    output logic [7:0] mem_wdata,
    output logic       miso,
    output logic       busy,
    output logic       done,
    output logic [7:0] rx_data,
    output logic [6:0] active_addr,
    output logic       active_mode
);

    localparam logic SAMPLE_ON_RISE = (CPOL == CPHA);

    logic       sclk_d;
    logic       ss_d;
    logic [7:0] cmd_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [7:0] tx_shift_reg;
    logic [2:0] cmd_bit_cnt;
    logic [2:0] data_bit_cnt;
    logic       in_cmd_phase;
    logic       in_read_phase;
    logic       in_write_phase;
    logic       read_load_pending;

    logic sclk_rise;
    logic sclk_fall;
    logic ss_rise;
    logic ss_fall;
    logic sample_edge;
    logic launch_edge;

    assign sclk_rise   = ~sclk_d & sclk;
    assign sclk_fall   = sclk_d & ~sclk;
    assign ss_rise     = ~ss_d & ss;
    assign ss_fall     = ss_d & ~ss;
    assign sample_edge = SAMPLE_ON_RISE ? sclk_rise : sclk_fall;
    assign launch_edge = SAMPLE_ON_RISE ? sclk_fall : sclk_rise;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            sclk_d            <= CPOL;
            ss_d              <= 1'b1;
            cmd_shift_reg     <= 8'h00;
            rx_shift_reg      <= 8'h00;
            tx_shift_reg      <= 8'h00;
            cmd_bit_cnt       <= 3'd7;
            data_bit_cnt      <= 3'd7;
            in_cmd_phase      <= 1'b0;
            in_read_phase     <= 1'b0;
            in_write_phase    <= 1'b0;
            read_load_pending <= 1'b0;
            mem_addr          <= 7'h00;
            mem_we            <= 1'b0;
            mem_wdata         <= 8'h00;
            miso              <= 1'b1;
            busy              <= 1'b0;
            done              <= 1'b0;
            rx_data           <= 8'h00;
            active_addr       <= 7'h00;
            active_mode       <= 1'b0;
        end else begin
            sclk_d <= sclk;
            ss_d   <= ss;
            mem_we <= 1'b0;
            done   <= 1'b0;

            if (ss_rise) begin
                cmd_shift_reg     <= 8'h00;
                rx_shift_reg      <= 8'h00;
                tx_shift_reg      <= 8'h00;
                cmd_bit_cnt       <= 3'd7;
                data_bit_cnt      <= 3'd7;
                in_cmd_phase      <= 1'b0;
                in_read_phase     <= 1'b0;
                in_write_phase    <= 1'b0;
                read_load_pending <= 1'b0;
                miso              <= 1'b1;
                busy              <= 1'b0;
            end else if (ss_fall) begin
                cmd_shift_reg     <= 8'h00;
                rx_shift_reg      <= 8'h00;
                tx_shift_reg      <= 8'h00;
                cmd_bit_cnt       <= 3'd7;
                data_bit_cnt      <= 3'd7;
                in_cmd_phase      <= 1'b1;
                in_read_phase     <= 1'b0;
                in_write_phase    <= 1'b0;
                read_load_pending <= 1'b0;
                miso              <= 1'b1;
                busy              <= 1'b1;
            end else if (!ss) begin
                if (sample_edge) begin
                    if (in_cmd_phase) begin
                        if (cmd_bit_cnt == 3'd0) begin
                            active_addr       <= cmd_shift_reg[6:0];
                            active_mode       <= mosi;
                            mem_addr          <= cmd_shift_reg[6:0];
                            data_bit_cnt      <= 3'd7;
                            in_cmd_phase      <= 1'b0;
                            rx_shift_reg      <= 8'h00;
                            read_load_pending <= 1'b0;

                            if (mosi) begin
                                in_write_phase <= 1'b1;
                                in_read_phase  <= 1'b0;
                            end else begin
                                in_write_phase    <= 1'b0;
                                in_read_phase     <= 1'b1;
                                read_load_pending <= 1'b1;
                            end
                        end else begin
                            cmd_shift_reg <= {cmd_shift_reg[6:0], mosi};
                            cmd_bit_cnt   <= cmd_bit_cnt - 1'b1;
                        end
                    end else if (in_write_phase) begin
                        if (data_bit_cnt == 3'd0) begin
                            mem_wdata      <= {rx_shift_reg[6:0], mosi};
                            rx_data        <= {rx_shift_reg[6:0], mosi};
                            mem_we         <= 1'b1;
                            in_write_phase <= 1'b0;
                            done           <= 1'b1;
                        end else begin
                            rx_shift_reg <= {rx_shift_reg[6:0], mosi};
                            data_bit_cnt <= data_bit_cnt - 1'b1;
                        end
                    end
                end

                if (launch_edge && in_read_phase) begin
                    if (read_load_pending) begin
                        miso              <= mem_rdata[7];
                        tx_shift_reg      <= {mem_rdata[6:0], 1'b0};
                        read_load_pending <= 1'b0;
                        if (data_bit_cnt != 3'd0) begin
                            data_bit_cnt <= data_bit_cnt - 1'b1;
                        end else begin
                            in_read_phase <= 1'b0;
                            done          <= 1'b1;
                        end
                    end else begin
                        miso         <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        if (data_bit_cnt == 3'd0) begin
                            in_read_phase <= 1'b0;
                            done          <= 1'b1;
                        end else begin
                            data_bit_cnt <= data_bit_cnt - 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
