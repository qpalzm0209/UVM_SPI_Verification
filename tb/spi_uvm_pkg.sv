package spi_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef virtual spi_if spi_vif_t;

    class spi_seq_item extends uvm_sequence_item;
        rand bit       mode;
        rand bit [6:0] addr;
        rand bit [7:0] data;

        bit [7:0] rx_data;

        `uvm_object_utils_begin(spi_seq_item)
            `uvm_field_int(mode,    UVM_DEFAULT)
            `uvm_field_int(addr,    UVM_DEFAULT)
            `uvm_field_int(data,    UVM_DEFAULT)
            `uvm_field_int(rx_data, UVM_DEFAULT | UVM_NOPACK)
        `uvm_object_utils_end

        function new(string name = "spi_seq_item");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf(
                "mode=%s addr=%0d tx=0x%02h rx=0x%02h",
                mode ? "WRITE" : "READ",
                addr,
                data,
                rx_data
            );
        endfunction
    endclass

    class spi_base_sequence extends uvm_sequence #(spi_seq_item);
        `uvm_object_utils(spi_base_sequence)

        function new(string name = "spi_base_sequence");
            super.new(name);
        endfunction

        protected task send_transfer(bit mode, bit [6:0] addr, bit [7:0] data);
            spi_seq_item req;

            req = spi_seq_item::type_id::create($sformatf("req_%0t", $time));
            start_item(req);
            req.mode = mode;
            req.addr = addr;
            req.data = data;
            finish_item(req);
        endtask
    endclass

    class spi_full_sweep_sequence extends spi_base_sequence;
        `uvm_object_utils(spi_full_sweep_sequence)

        localparam int unsigned ADDR_MIN = 0;
        localparam int unsigned ADDR_MAX = 127;
        bit [7:0] patterns [0:3];

        function new(string name = "spi_full_sweep_sequence");
            super.new(name);
            patterns[0] = 8'h00;
            patterns[1] = 8'h0f;
            patterns[2] = 8'hf0;
            patterns[3] = 8'hff;
        endfunction

        task body();
            for (int unsigned addr_idx = ADDR_MIN; addr_idx <= ADDR_MAX; addr_idx++) begin
                foreach (patterns[pat_idx]) begin
                    send_transfer(1'b1, addr_idx[6:0], patterns[pat_idx]);
                    send_transfer(1'b0, addr_idx[6:0], 8'h00);
                end
            end
        endtask
    endclass

    class spi_sequencer extends uvm_sequencer #(spi_seq_item);
        `uvm_component_utils(spi_sequencer)

        function new(string name = "spi_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class spi_driver extends uvm_driver #(spi_seq_item);
        `uvm_component_utils(spi_driver)

        spi_vif_t vif;

        function new(string name = "spi_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(spi_vif_t)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "Virtual interface not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            spi_seq_item req;

            drive_idle();
            wait_for_reset_release();

            forever begin
                seq_item_port.get_next_item(req);
                drive_transfer(req);
                seq_item_port.item_done();
            end
        endtask

        protected task drive_idle();
            vif.drv_cb.start   <= 1'b0;
            vif.drv_cb.tx_data <= 8'h00;
            vif.drv_cb.addr    <= 7'h00;
            vif.drv_cb.mode    <= 1'b0;
        endtask

        protected task wait_for_reset_release();
            while (vif.rst) begin
                @(vif.drv_cb);
                drive_idle();
            end
        endtask

        protected task drive_transfer(spi_seq_item req);
            while (vif.rst) begin
                @(vif.drv_cb);
                drive_idle();
            end

            while (vif.drv_cb.master_busy) begin
                @(vif.drv_cb);
            end

            vif.drv_cb.addr    <= req.addr;
            vif.drv_cb.mode    <= req.mode;
            vif.drv_cb.tx_data <= req.mode ? req.data : 8'h00;
            vif.drv_cb.start   <= 1'b0;
            @(vif.drv_cb);

            vif.drv_cb.start <= 1'b1;
            @(vif.drv_cb);

            vif.drv_cb.start <= 1'b0;
            while (!vif.drv_cb.master_done) begin
                @(vif.drv_cb);
            end

            @(vif.drv_cb);
            drive_idle();
        endtask
    endclass

    class spi_monitor extends uvm_component;
        `uvm_component_utils(spi_monitor)

        spi_vif_t vif;
        uvm_analysis_port #(spi_seq_item) ap;

        function new(string name = "spi_monitor", uvm_component parent = null);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(spi_vif_t)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "Virtual interface not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            spi_seq_item item;

            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.rst) begin
                    continue;
                end

                if (vif.mon_cb.start) begin
                    item = spi_seq_item::type_id::create($sformatf("mon_item_%0t", $time), this);
                    item.mode = vif.mon_cb.mode;
                    item.addr = vif.mon_cb.addr;
                    item.data = vif.mon_cb.tx_data;

                    do begin
                        @(vif.mon_cb);
                    end while (!vif.mon_cb.master_done && !vif.mon_cb.rst);

                    if (vif.mon_cb.rst) begin
                        continue;
                    end

                    item.rx_data = vif.mon_cb.master_rx_data;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class spi_agent extends uvm_agent;
        `uvm_component_utils(spi_agent)

        spi_sequencer sequencer;
        spi_driver    driver;
        spi_monitor   monitor;

        function new(string name = "spi_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            monitor = spi_monitor::type_id::create("monitor", this);

            if (is_active == UVM_ACTIVE) begin
                sequencer = spi_sequencer::type_id::create("sequencer", this);
                driver    = spi_driver::type_id::create("driver", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (is_active == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction
    endclass

    class spi_scoreboard extends uvm_subscriber #(spi_seq_item);
        `uvm_component_utils(spi_scoreboard)

        localparam int unsigned EXPECTED_WRITES = 512;
        localparam int unsigned EXPECTED_READS  = 512;

        bit [7:0] golden_mem [0:127];
        int unsigned total_cnt;
        int unsigned write_cnt;
        int unsigned read_cnt;
        int unsigned pass_cnt;
        int unsigned fail_cnt;

        function new(string name = "spi_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            reset_model();
        endfunction

        function void reset_model();
            foreach (golden_mem[idx]) begin
                golden_mem[idx] = 8'h00;
            end
        endfunction

        virtual function void write(spi_seq_item t);
            bit [7:0] expected;

            total_cnt++;
            if (t.mode) begin
                write_cnt++;
                golden_mem[t.addr] = t.data;
            end else begin
                read_cnt++;
                expected = golden_mem[t.addr];
                if (t.rx_data === expected) begin
                    pass_cnt++;
                    `uvm_info(
                        "SPI_SWEEP",
                        $sformatf("addr[%0d] : [write data: %02h] [read feedback: %02h] test pass", t.addr, expected, t.rx_data),
                        UVM_LOW
                    )
                end else begin
                    fail_cnt++;
                    `uvm_error(
                        "SPI_SWEEP",
                        $sformatf(
                            "addr[%0d] : [%02h => %02h] test fail",
                            t.addr,
                            expected,
                            t.rx_data
                        )
                    )
                end
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);

            if (write_cnt != EXPECTED_WRITES) begin
                `uvm_error(
                    "SPI_SB_SUMMARY",
                    $sformatf("Expected %0d writes but observed %0d", EXPECTED_WRITES, write_cnt)
                )
            end

            if (read_cnt != EXPECTED_READS) begin
                `uvm_error(
                    "SPI_SB_SUMMARY",
                    $sformatf("Expected %0d reads but observed %0d", EXPECTED_READS, read_cnt)
                )
            end

            `uvm_info(
                "SPI_SB_SUMMARY",
                $sformatf(
                    "SPI full sweep result: pass=%0d fail=%0d",
                    pass_cnt,
                    fail_cnt
                ),
                UVM_NONE
            )

            `uvm_info(
                "SPI_SB_SUMMARY",
                $sformatf(
                    "SPI transaction summary: total=%0d write=%0d read=%0d",
                    total_cnt,
                    write_cnt,
                    read_cnt
                ),
                UVM_NONE
            )

            if ((fail_cnt == 0) && (write_cnt == EXPECTED_WRITES) && (read_cnt == EXPECTED_READS)) begin
                `uvm_info("SPI_SB_SUMMARY", "SPI full sweep overall PASS", UVM_NONE)
            end else begin
                `uvm_info("SPI_SB_SUMMARY", "SPI full sweep overall FAIL", UVM_NONE)
            end
        endfunction
    endclass

    class spi_env extends uvm_env;
        `uvm_component_utils(spi_env)

        spi_agent      agent;
        spi_scoreboard scoreboard;

        function new(string name = "spi_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent      = spi_agent::type_id::create("agent", this);
            scoreboard = spi_scoreboard::type_id::create("scoreboard", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.monitor.ap.connect(scoreboard.analysis_export);
        endfunction
    endclass

    class spi_base_test extends uvm_test;
        `uvm_component_utils(spi_base_test)

        spi_env env;

        function new(string name = "spi_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = spi_env::type_id::create("env", this);
            uvm_top.set_timeout(2s, 1);
        endfunction
    endclass

    class spi_full_sweep_test extends spi_base_test;
        `uvm_component_utils(spi_full_sweep_test)

        function new(string name = "spi_full_sweep_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            spi_full_sweep_sequence seq;

            phase.raise_objection(this);
            seq = spi_full_sweep_sequence::type_id::create("seq");
            seq.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass
endpackage
