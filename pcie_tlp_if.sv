interface pcie_tlp_if(input logic clk);
  logic         req_valid;
  logic         req_ready;
  logic [127:0] req_tlp;
  logic         cpl_valid;
  logic         cpl_ready;
  logic [127:0] cpl_tlp;
endinterface