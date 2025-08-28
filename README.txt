================================================================================
                    MIPS PIPELINE PROCESSOR - Design Under Test (DUT)
================================================================================

OVERVIEW
--------
This directory contains a complete implementation of a 5-stage pipelined MIPS 
processor designed for educational purposes. The processor implements a subset 
of the MIPS instruction set with advanced pipeline optimization techniques 
including hazard detection, data forwarding, and performance monitoring.

ARCHITECTURE
------------
The processor implements a classic 5-stage MIPS pipeline:

1. INSTRUCTION FETCH (IF)   - Fetches instructions from program memory
2. INSTRUCTION DECODE (ID)  - Decodes instructions and reads registers  
3. EXECUTE (EX)            - Performs ALU operations and address calculations
4. MEMORY ACCESS (MEM)     - Handles load/store operations
5. WRITE BACK (WB)         - Writes results back to register file

KEY FEATURES
------------
• 32-bit MIPS instruction set architecture
• 5-stage pipeline with hazard resolution
• Data forwarding unit to minimize pipeline stalls
• Branch prediction and control hazard handling
• Performance counters for IPC analysis
• Single-port data memory (256 words)
• 32-entry register file with register 0 hardwired to zero
• Support for R-type, I-type, and J-type instructions
• Hybrid clocking scheme for optimized control flow handling


PIPELINE OPTIMIZATION
--------------------
• Data Forwarding: Eliminates most data hazards by forwarding results from 
  MEM and WB stages directly to EX stage
• Hazard Detection: Automatically detects load-use hazards and inserts 
  pipeline stalls when necessary
• Branch Handling: Early branch resolution in ID stage with forwarding 
  support for branch comparisons
• Hybrid Clocking: PC updates on falling edge, pipeline stages on rising 
  edge to eliminate control hazard bubbles


MAJOR COMPONENTS
---------------
IFETCH.VHD                  - Instruction fetch stage with PC management
IDECODE.VHD                 - Instruction decode stage with register file
EXECUTE.VHD                 - Execute stage with ALU and barrel shifter
DMEMORY.VHD                 - Memory access stage with data memory
control.vhd                 - Main control unit for instruction decoding
Hazard_detection_unit.vhd   - Detects pipeline hazards
ForwordingUnit.vhd          - Manages data forwarding paths
MIPS.vhd                    - Top-level processor integration
aux_package.vhd             - Component declarations and utilities

PERFORMANCE MONITORING
---------------------
The processor includes comprehensive performance counters:
• Instruction count
• Clock cycle count  
• Stall count (pipeline stalls due to hazards)
• Flush count (control flow changes)
• IPC calculation: Instructions / Clock_Cycles

CLOCKING ARCHITECTURE
--------------------
• Main pipeline stages: Rising edge triggered
• PC register: Falling edge triggered
• Memory operations: Inverted clock for timing optimization
• This hybrid approach eliminates pipeline bubbles on branches/jumps

MEMORY INITIALIZATION
--------------------
• ITCM.hex: Program memory initialization (instructions)
• DTCM.hex: Data memory initialization (data values)
• Both files use hexadecimal format, one word per line


PIPELINE TIMING
--------------
The processor can achieve close to 1 IPC (Instructions Per Clock) performance
with proper instruction scheduling. Performance is affected by:
• Load-use hazards: 1 cycle stall
• Branch misprediction: No penalty due to hybrid clocking
• Memory access patterns: Single-cycle memory access
