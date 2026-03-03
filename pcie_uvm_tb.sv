//===========================================================
// Project: PCIe Endpoint UVM Verification Environment
// Author: Ali Ahmadirad
// Description: Complete UVM TB with Functional Coverage
//===========================================================

`timescale 1ns/1ps
import uvm_pkg::*; 
`include "uvm_macros.svh"

//-----------------------------------------------------------
// 1. Transaction Object (TLP)
//-----------------------------------------------------------
typedef enum logic [7:0] {
  MEM_RD  = 8'h00,
  MEM_WR  = 8'h01,
  CPL     = 8'h0A,
  UR_CPL  = 8'h0B
} tlp_type_e;

class pcie_tlp extends uvm_sequence_item;
  rand tlp_type_e   tlp_type;
  rand logic [31:0] addr;
  rand logic [31:0] data;
  bit               is_completion;

  `uvm_object_utils_begin(pcie_tlp)
    `uvm_field_enum(tlp_type_e, tlp_type, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(is_completion, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name="pcie_tlp"); super.new(name); endfunction

  // Focus on the 4 defined registers
  constraint addr_c { addr inside {32'h0000, 32'h0004, 32'h0008, 32'h000C}; }
endclass

//-----------------------------------------------------------
// 2. Driver
//-----------------------------------------------------------
class pcie_driver extends uvm_driver #(pcie_tlp);
  `uvm_component_utils(pcie_driver)
  virtual pcie_tlp_if vif;
  uvm_analysis_port #(pcie_tlp) drv_ap;

  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv_ap = new("drv_ap", this);
    if(!uvm_config_db#(virtual pcie_tlp_if)::get(this,"","vif",vif))
      `uvm_fatal("DRV","Virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    pcie_tlp tr;
    forever begin
      seq_item_port.get_next_item(tr);
      drive_tlp(tr);
      drv_ap.write(tr); 
      seq_item_port.item_done();
    end
  endtask

  task drive_tlp(pcie_tlp tr);
    @(posedge vif.clk);
    vif.req_valid <= 1'b1;
    vif.req_tlp[127:120] <= tr.tlp_type;
    vif.req_tlp[119:88]  <= tr.addr;
    vif.req_tlp[31:0]    <= tr.data;
    wait(vif.req_ready);
    @(posedge vif.clk);
    vif.req_valid <= 1'b0;
  endtask
endclass

//-----------------------------------------------------------
// 3. Monitor
//-----------------------------------------------------------
class pcie_monitor extends uvm_monitor;
  `uvm_component_utils(pcie_monitor)
  virtual pcie_tlp_if vif;
  uvm_analysis_port #(pcie_tlp) ap;

  function new(string name, uvm_component parent); super.new(name,parent); ap = new("ap",this); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_tlp_if)::get(this,"","vif",vif))
      `uvm_fatal("MON","Virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    pcie_tlp tr;
    forever begin
      @(posedge vif.clk);
      if(vif.cpl_valid) begin
        tr = pcie_tlp::type_id::create("tr");
        if (!$cast(tr.tlp_type, vif.cpl_tlp[127:120])) `uvm_error("MON", "Cast failed")
        tr.addr = vif.cpl_tlp[119:88];
        tr.data = vif.cpl_tlp[31:0];
        ap.write(tr);
      end
    end
  endtask
endclass

//-----------------------------------------------------------
// 4. Functional Coverage (NEW)
//-----------------------------------------------------------
class pcie_coverage extends uvm_subscriber #(pcie_tlp);
  `uvm_component_utils(pcie_coverage)

  pcie_tlp t_item;

  covergroup pcie_cg;
    option.per_instance = 1;
    option.comment = "Coverage for PCIe Register Access";

    // 1. Check if we sent both Reads and Writes
    cp_type: coverpoint t_item.tlp_type {
      bins b_read  = {MEM_RD};
      bins b_write = {MEM_WR};
    }

    // 2. Check if we hit all 4 registers
    cp_addr: coverpoint t_item.addr {
      bins reg0 = {32'h0000};
      bins reg1 = {32'h0004};
      bins reg2 = {32'h0008};
      bins reg3 = {32'h000C};
    }

    // 3. CROSS COVERAGE: Did we READ and WRITE to EVERY register?
    cross_type_addr: cross cp_type, cp_addr;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    pcie_cg = new();
  endfunction

  function void write(pcie_tlp t);
    t_item = t;
    pcie_cg.sample();
  endfunction
endclass

//-----------------------------------------------------------
// 5. Scoreboard
//-----------------------------------------------------------
class pcie_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pcie_scoreboard)
  `uvm_analysis_imp_decl(_req)
  `uvm_analysis_imp_decl(_cpl)

  uvm_analysis_imp_req #(pcie_tlp, pcie_scoreboard) req_imp;
  uvm_analysis_imp_cpl #(pcie_tlp, pcie_scoreboard) cpl_imp;

  logic [31:0] shadow_regs [4];
  pcie_tlp exp_q[$];

  function new(string name, uvm_component parent);
    super.new(name,parent);
    req_imp = new("req_imp",this);
    cpl_imp = new("cpl_imp",this);
    foreach(shadow_regs[i]) shadow_regs[i] = 32'h0;
  endfunction

  function void write_req(pcie_tlp tr);
    if(tr.tlp_type == MEM_WR) shadow_regs[tr.addr[3:2]] = tr.data;
    else if(tr.tlp_type == MEM_RD) begin
      pcie_tlp exp = pcie_tlp::type_id::create("exp");
      exp.data = shadow_regs[tr.addr[3:2]];
      exp_q.push_back(exp);
    end
  endfunction

  function void write_cpl(pcie_tlp tr);
    pcie_tlp exp;
    if(exp_q.size() > 0) begin
      exp = exp_q.pop_front();
      if(tr.data !== exp.data) `uvm_error("SB", "Mismatch!")
      else `uvm_info("SB", $sformatf("Match! Data: %h", tr.data), UVM_LOW)
    end
  endfunction
endclass

//-----------------------------------------------------------
// 6. Environment
//-----------------------------------------------------------
class pcie_env extends uvm_env;
  `uvm_component_utils(pcie_env)
  pcie_driver drv; pcie_monitor mon; pcie_scoreboard sb; 
  pcie_coverage cov; uvm_sequencer #(pcie_tlp) sqr;

  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  function void build_phase(uvm_phase phase);
    drv=pcie_driver::type_id::create("drv",this); mon=pcie_monitor::type_id::create("mon",this);
    sb=pcie_scoreboard::type_id::create("sb",this); cov=pcie_coverage::type_id::create("cov",this);
    sqr=uvm_sequencer#(pcie_tlp)::type_id::create("sqr",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
    drv.drv_ap.connect(sb.req_imp);
    drv.drv_ap.connect(cov.analysis_export); // Connect Driver to Coverage
    mon.ap.connect(sb.cpl_imp);
  endfunction
endclass

//-----------------------------------------------------------
// 7. Sequence & Test
//-----------------------------------------------------------
class pcie_base_seq extends uvm_sequence #(pcie_tlp);
  `uvm_object_utils(pcie_base_seq)
  function new(string name="pcie_base_seq"); super.new(name); endfunction
  task body();
    pcie_tlp tr;
    // Increase repeat count to 20 to ensure we hit all cross-coverage bins
    repeat(20) begin
      tr = pcie_tlp::type_id::create("tr");
      start_item(tr); 
      if(!tr.randomize()) `uvm_fatal("SEQ", "Rand fail")
      finish_item(tr);
    end
  endtask
endclass

class pcie_test extends uvm_test;
  `uvm_component_utils(pcie_test)
  pcie_env env;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase); env=pcie_env::type_id::create("env",this); endfunction
  task run_phase(uvm_phase phase);
    pcie_base_seq seq; phase.raise_objection(this);
    seq = pcie_base_seq::type_id::create("seq");
    seq.start(env.sqr); #100;
    phase.drop_objection(this);
  endtask
endclass

//-----------------------------------------------------------
// 8. Top Module
//-----------------------------------------------------------
module tb_top;
  logic clk=0; logic rst_n; pcie_tlp_if vif(clk);
  always #5 clk = ~clk;
  initial begin rst_n=0; #20 rst_n=1; end
  pcie_endpoint dut(.clk(clk), .rst_n(rst_n), .dut_if(vif));
  initial begin
    uvm_config_db#(virtual pcie_tlp_if)::set(null, "*", "vif", vif);
    run_test("pcie_test");
  end
endmodule