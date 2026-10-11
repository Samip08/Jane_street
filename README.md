# Protocol Emulator ASIC

## Overview

This repository contains the RTL implementation, verification testbenches, assembly test programs, and project documentation for the protocol emulator ASIC. The architecture is designed to execute timing-critical communication protocols including UART, I2C, SPI, and JTAG under strict hardware resource constraints.

## Repository Structure

* `assembly/`: Contains assembly source files and protocol test programs.
* `docs/`: Contains project documentation and Minutes of Meetings (MoM).
* `rtl/`: Contains Verilog RTL source files for the processing core, memory blocks, and pin multiplexers.
* `testbenches/`: Contains simulation testbenches for functional verification.
* `resources/`: any resources from the official jane street page or files to be used for tapeeout.
* `README.md`: Project description and execution guide.

## Execution Guidelines (Icarus Verilog)

To compile and execute simulations of the RTL design using Icarus Verilog from the command line, follow the procedure below.

1. **Clone and Navigate:** Setup.
Access the command line interface, clone the repository, and change the current working directory into the root folder of the project.


2. **Compile Simulation Files:** Compilation.
Invoke the Icarus Verilog compiler to process all source files within the RTL directory alongside the designated testbench file.


3. **Execute Simulation Binary:** Simulation.
Run the generated simulation output file using the Verilog Virtual Processor execution tool.


### Command Line Reference

```bash
# Clone the repository and enter the project directory
git clone https://github.com/Samip08/Jane_street.git
cd Jane_street

# Compile the design using Icarus Verilog
iverilog -o sim_output rtl/*.v testbenches/<testbench_filename>.v

#if the rtl files don't compile try individually adding the rtl files to compile
iverilog -o sim_output rtl/<file_name.v> rtl/<file_name.v> rtl/<file_name.v> testbenches/<file_name.v>
vvp sim_output

# Run the generated simulation binary
vvp sim_output

```