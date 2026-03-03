# PCIe Endpoint Verification Environment (UVM)

This repository contains a complete **Universal Verification Methodology (UVM)** environment for verifying a PCIe Transaction Layer Endpoint. The environment uses constrained-random stimulus to verify Memory Write (MEM_WR) and Memory Read (MEM_RD) operations against a SystemVerilog RTL model.



## 🛠 Features
* **UVM Architecture**: Implements a full factory-based UVM environment (Agent, Driver, Monitor, Sequencer, Scoreboard).
* **Transaction Layer**: Models PCIe TLPs (Transaction Layer Packets) including Header and Data payloads.
* **Self-Checking Scoreboard**: Features a "Shadow Register" model to verify that data read from the Endpoint matches the last data written.
* **Protocol Handshaking**: Verifies the `valid/ready` handshake mechanism between the Root Complex (TB) and Endpoint (DUT).
* **Automation**: Includes a Questasim `run.do` script for one-click compilation and simulation.

## 📂 Project Structure
* `pcie_endpoint.sv`: The PCIe Endpoint design logic.
* `pcie_tlp_if.sv`: SystemVerilog Interface defining the PCIe bus.
* `pcie_uvm_tb.sv`: The complete UVM Testbench source code.
* `run.do`: Tcl script for Questasim automation.

## 🚀 How to Run
1. Clone the repository.
2. Open **QuestaSim**.
3. Set the directory to the project root.
4. Run the following command in the transcript:
   do run.do
