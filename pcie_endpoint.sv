module pcie_endpoint (
  input  logic clk,
  input  logic rst_n,
  pcie_tlp_if dut_if
);
  logic [31:0] regs [4];
  assign dut_if.req_ready = 1'b1;
  assign dut_if.cpl_ready = 1'b1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      foreach(regs[i]) regs[i] <= 32'h0;
      dut_if.cpl_valid <= 1'b0;
    end else if (dut_if.req_valid && dut_if.req_ready) begin
      if (dut_if.req_tlp[127:120] == 8'h01) begin // MEM_WR
        case (dut_if.req_tlp[119:88])
          32'h0000: regs[0] <= dut_if.req_tlp[31:0];
          32'h0004: regs[1] <= dut_if.req_tlp[31:0];
          32'h0008: regs[2] <= dut_if.req_tlp[31:0];
          32'h000C: regs[3] <= dut_if.req_tlp[31:0];
        endcase
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) dut_if.cpl_valid <= 1'b0;
    else begin
      dut_if.cpl_valid <= 1'b0;
      if(dut_if.req_valid && dut_if.req_tlp[127:120] == 8'h00) begin // MEM_RD
        dut_if.cpl_valid <= 1'b1;
        dut_if.cpl_tlp[127:120] <= 8'h0A; // CPL
        dut_if.cpl_tlp[119:88]  <= dut_if.req_tlp[119:88];
        case(dut_if.req_tlp[119:88])
          32'h0000: dut_if.cpl_tlp[31:0] <= regs[0];
          32'h0004: dut_if.cpl_tlp[31:0] <= regs[1];
          32'h0008: dut_if.cpl_tlp[31:0] <= regs[2];
          32'h000C: dut_if.cpl_tlp[31:0] <= regs[3];
          default:  dut_if.cpl_tlp[31:0] <= 32'hDEADBEEF;
        endcase
      end
    end
  end
endmodule