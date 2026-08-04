# MIPS Pipeline Microcontroller

A 5-stage pipelined MIPS processor integrated with a peripheral set into a
complete microcontroller, targeting Intel/Altera Cyclone FPGAs.

Verified by golden-model co-simulation: every register and memory write the
hardware commits is diffed against a reference instruction-set simulator.

---

## 1. Architecture

### Pipeline

| Stage | Name | Function |
|-------|------|----------|
| IF | Instruction Fetch | PC management, ITCM read |
| ID | Instruction Decode | Register file, sign extension, branch resolution |
| EX | Execute | ALU, shifter, multiplier, forwarding muxes |
| MEM | Memory Access | DTCM and memory-mapped peripheral access |
| WB | Write Back | Result selection, register file write |

### Hazard handling

- **Full forwarding** — EX→EX and MEM→EX (`ForwardA`/`ForwardB`), plus a
  separate MEM→ID path for branch operands (`ForwardA_Branch`/`ForwardB_Branch`).
- **Load-use interlock** — one-cycle stall when an instruction in EX is a load
  whose destination is a source of the instruction in ID.
- **Branch interlock** — stalls when a branch operand is still in EX, or is
  being produced by a load currently in MEM.
- **Early branch resolution** — branches are compared in ID, not EX, so a taken
  branch costs one flushed instruction rather than two.

There is **no branch predictor**. Branches are resolved early and the
following instruction is flushed on a taken branch or jump. There are **no
branch delay slots** — the flush handles it.

### Clocking

| Element | Edge |
|---------|------|
| PC register | rising |
| Pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) | rising |
| Register file write (`Idecode`) | **falling** |
| ITCM / DTCM (`altsyncram`) | **falling** (`not clk_i`) |
| Memory-mapped peripheral registers in `MCU.vhd` | **falling** |
| Interrupt controller | **falling** |

> **Known limitation.** The mixed rising/falling scheme means any path from a
> rising-edge register into a falling-edge register has only *half* a clock
> period to settle. This is a significant Fmax limiter and is the top candidate
> for future optimization. The falling-edge register file is a single-cycle-MIPS
> convention that is unnecessary here, since a forwarding unit is already
> present.

---

## 2. Instruction set

A subset of MIPS32. All instructions are single-word and there are no delay
slots.

| Type | Instructions |
|------|-------------|
| Arithmetic/logic (R) | `add` `sub` `and` `or` `xor` `slt` `mov` |
| Multiply (R, op 011100) | `mul` (low 32 bits only, no `HI`/`LO`) |
| Shift (R) | `sll` `srl` (immediate shift amount) |
| Immediate (I) | `addi` `andi` `ori` `xori` `slti` `lui` |
| Memory (I) | `lw` `sw` (word only) |
| Branch (I) | `beq` `bne` |
| Jump (J/R) | `j` `jal` `jr` |

**Deliberate deviations from MIPS32**, both consequences of the 256-word memories:

- Branch offsets and jump targets use only the low **8 bits** of the
  instruction, and are **word** addresses, not byte addresses. Code is limited
  to 256 instructions and branches to ±127 words.
- `jal` stores a word address in `$ra`, not a byte address.

Not implemented: `HI`/`LO` registers, `div`, `sltu`, byte/halfword memory
access, unaligned access, coprocessor 0, exceptions and traps, overflow
detection on `add`/`addi`.

---

## 3. Memory map

Addresses at or above `0x800` are decoded as peripherals; everything below goes
to DTCM.

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| `0x000`–`0x3FF` | DTCM | R/W | 256 words of data memory |
| `0x800` | `LEDR` | W | 8 red LEDs |
| `0x804` | `HEX0_HEX1` | W | Seven-segment pair |
| `0x808` | `HEX2_HEX3` | W | Seven-segment pair |
| `0x80C` | `HEX4_HEX5` | W | Seven-segment pair |
| `0x810` | `SW` | R | 8 slide switches |
| `0x811` | `KEY` | R | Push buttons |
| `0x818` | `UCTL` | R/W | UART control |
| `0x81C` | `BTCTL` | W | Basic timer control |
| `0x820` | `BTCNT` | R | Basic timer count |
| `0x824` | `BTCCR0` | W | Timer compare 0 |
| `0x828` | `BTCCR1` | W | Timer compare 1 |
| `0x82C` | `FIRCTL` | R/W | FIR control (W) / status (R) |
| `0x830` | `FIRIN` | W | FIR sample input |
| `0x834` | `FIROUT` | R | FIR filtered output |
| `0x838` | `COEF3_0` | R/W | FIR coefficients h3..h0 |
| `0x83C` | `COEF7_4` | R/W | FIR coefficients h7..h4 |
| `0x840` | `IE` | W | Interrupt enable |
| `0x841` | `IFG` | W | Interrupt flags |
| `0x842` | `TYPE` | R | Interrupt vector type |

**`FIRCTL` bits** — write: `[0]` FIRENA, `[1]` FIRRST, `[4]` FIFORST,
`[5]` FIFOWEN (self-clearing). Read: `[2]` FIFOEMPTY, `[3]` FIFOFULL.

---

## 4. Peripherals

**FIR filter accelerator** — 8-tap, UQ24.0 samples, UQ0.8 coefficients,
16-deep input FIFO, saturating output scaler. Runs in a separate clock domain
(`FIRCLK`, derived from the system clock by `CLOCK_DIVIDER`) and crosses back
to the CPU domain through a req/ack toggle handshake. Raises `FIRIFG` per
output sample.

**UART** — `UART_TX.vhd` / `UART_RX.vhd` with a shared control register.

**Basic timer** — free-running counter with two compare registers and a PWM
output.

**GPIO** — LEDs, switches, buttons, and six seven-segment displays via
`SevenSegDecoder`.

**Interrupt controller** — priority encoder over eight sources, producing a
vector `TYPE` that indexes a vector table held in low DTCM.

---

## 5. File inventory

### CPU core
| File | Role |
|------|------|
| `MIPS.vhd` | Top-level core: stage instantiation, pipeline registers, bus interface |
| `IFETCH.VHD` | PC, next-PC mux, ITCM (`altsyncram` ROM) |
| `IDECODE.VHD` | Register file, sign extension, branch comparator, GIE/EPC |
| `EXECUTE.VHD` | Forwarding muxes, ALU operand selection |
| `ALU.vhd` | Arithmetic, logic, shift, multiply, signed compare |
| `ALU_CONTROL.vhd` | `ALUOp` + `funct` → ALU operation |
| `CONTROL.VHD` | Main opcode decoder |
| `HazardUnit.vhd` | Forwarding selects, load-use and branch stalls |
| `DMEMORY.VHD` | DTCM (`altsyncram` single-port RAM) |
| `WRITE_BACK.vhd` | Result mux, JAL return-address mux |

### System
| File | Role |
|------|------|
| `MCU.vhd` | Top level: CPU + peripherals + memory-mapped registers |
| `OptAddrDecoder.vhd` | Peripheral chip-select decode |
| `InterruptController.vhd` | Priority encoder, vector generation |
| `GPIO.vhd`, `SevenSegDecoder.vhd` | I/O and display |
| `InputPeripheral.vhd`, `OutputPeripheral.vhd` | Generic I/O register blocks |
| `BTIMER.vhd` | Basic timer / PWM |
| `UART.vhd`, `UART_TX.vhd`, `UART_RX.vhd` | Serial interface |
| `FIR_filter.vhd` | FIR accelerator with FIFO and CDC handshake |
| `CLOCK_DIVIDER.vhd` | Generates `FIRCLK` |
| `aux_package.vhd` | Component declarations |
| `cond_compilation_package.vhd` | Build-time configuration |

### Verification
| File | Role |
|------|------|
| `retire_tracer.vhd` | Simulation-only observer; dumps committed effects |
| `tb_cpu.vhd` | Stimulus-only bench for co-simulation tests |
| `tb_fir.vhd` | Self-checking FIR end-to-end bench |
| `iss.py` | Golden-model instruction-set simulator |
| `compare.py` | Trace differ |
| `asm.py` | Two-pass assembler → Intel HEX |

---

## 6. Verification

### Golden-model co-simulation

Rather than hand-written expected values, the design is checked against a
reference ISS. `retire_tracer.vhd` records every architectural effect the
hardware commits:

- **register writes**, sampled at WB
- **memory writes**, sampled at MEM

`iss.py` runs the same binary and emits the same two streams. `compare.py`
diffs them and reports the first divergence with context.

Effect streams are used instead of per-instruction state comparison because the
pipeline registers carry no `valid` bit, so a retiring instruction cannot be
distinguished from a flushed bubble at WB. Bubbles commit nothing, so they
filter themselves out.

`iss.py` has a `STRICT_RTL` flag. With it set, the model reproduces the
design's deliberate deviations (8-bit word-addressed jumps, no delay slots).
Cleared, it models architectural MIPS, so any divergence is a spec violation
rather than an implementation bug. This second mode is how the `ANDI`/`XORI`
and `SLT` bugs listed in section 8 were found.

### Test suite

| Test | Coverage | Result |
|------|----------|--------|
| `test_cpu.asm` | Forwarding (EX→EX, MEM→EX, WB→EX), load-use stall, both branch-stall cases, taken/not-taken `beq`/`bne`, `j`/`jal`/`jr`, all ALU ops, `$zero` write suppression | 43/43 reg, 5/5 mem |
| `test_arch.asm` | ISA-deviation hunter: immediates across the bit-15 boundary, `SLT` with overflowing subtraction | 20/20 |
| `test_isa.asm` | Post-fix regression: sign- vs zero-extension boundaries, negative load/store offsets, `SLT` corner cases | 39/39 reg, 5/5 mem |
| `test_fir.asm` + `tb_fir` | FIR end-to-end: coefficient load, FIFO streaming, interrupt-driven output collection | 8/8 outputs |
| ALU testbench | 189 self-checking vectors, all opcodes | 189/189 |

### Running

```bash
# 1. assemble
python3 asm.py test_cpu.asm --itcm ITCM.hex --dtcm DTCM.hex

# 2. golden model
python3 iss.py --itcm ITCM.hex --dtcm DTCM.hex --out golden

# 3. RTL (ModelSim)
do run_cpu.do

# 4. diff
python3 compare.py golden.reg.trace rtl.reg.trace
python3 compare.py golden.mem.trace rtl.mem.trace
```

Exit code 0 = match, 1 = divergence.

The FIR bench is self-checking and needs no comparison step:
```
do run_fir.do
```

---

## 7. Build configuration

| Parameter | Simulation | Synthesis |
|-----------|-----------|-----------|
| `SIM` | `TRUE` | `FALSE` |
| `MemWidth` | `8` | `10` |

`MemWidth` **must** be 8 when `SIM => TRUE`. The `SIM` branch in `IFETCH.VHD`
drives `Mem_Addr` from `PC(9 downto 2)`, which is 8 bits; `MemWidth => 10`
causes a bound-check failure on the first instruction fetch.

`SIM` also selects the reset polarity in `MCU.vhd`
(`resetSim <= reset WHEN SIM ELSE not reset`).

`retire_tracer` is wrapped in `IF SIM GENERATE` inside `MIPS.vhd`, so its file
I/O never reaches synthesis. The file must still be in the Quartus project for
analysis to resolve the entity, but it contributes no logic.

### Memory initialization

`ITCM.hex` and `DTCM.hex` are Intel HEX with one 4-byte record per 32-bit word,
where the address field is a **word** index, not a byte address. Generated by
`asm.py`. The `init_file` paths in `IFETCH.VHD` and `DMEMORY.VHD` must point at
them.

---

## 8. Status

### Timing
Fmax **104 MHz** (Cyclone, slow model). Improved from 100 MHz by removing a
32-bit mux from the EX critical path during the SLT correctness fix.

### Recently fixed

- **`ANDI`/`XORI` sign-extended their immediates.** Only `ORI` was exempted in
  `IDECODE.VHD`, so any mask above `0x7FFF` was corrupted. All three logical
  immediates now zero-extend, per MIPS32.
- **`SLT`/`SLTI` returned the raw sign bit of `A-B`.** That subtraction
  overflows whenever the operands have opposite signs, so comparisons involving
  large-magnitude values inverted. Now resolved with a proper signed compare
  inside the ALU, sharing a single subtractor with `SUB`.
- **Pipeline registers had no reset branch.** While reset was asserted the PC
  was pinned at 0, so instruction 0 was re-fetched every cycle and copies
  filled every stage, all retiring on reset release. Control bits are now
  cleared during reset.
- **`MIPS.vhd` read its own output ports** (illegal in VHDL-93). Replaced with
  internal shadow signals.
- **FIR datapath was incomplete** and its CDC handshake deadlocked on
  desynchronized reset. Both fixed; bench went from 10/43 to 43/43.

### Known issues

| Issue | Impact |
|-------|--------|
| Mixed rising/falling clock edges | Halves the available period on cross-edge paths; main Fmax limiter |
| 32×32 combinational multiplier in EX | Large single-cycle delay; candidate for pipelining or multicycle constraint |
| `IFG` (`0x841`) has no read path in the `DataBus` mux | Reads return 0; the ISR's read-modify-write clear works only by accident |
| Duplicate `FIRIFG` on `IntrSrc` bits 7 and 6 | FIR can vector through two different `TYPE` values |
| `FIRCLK` generated in fabric by `CLOCK_DIVIDER` | Gated clock, poor skew, awkward to constrain; should be a PLL output or a clock enable |
| Performance counter ports (`CLKCNT`, `STCNT`, `FHCNT`, `BPADD`) declared but never driven | IPC measurement not yet available |
| Timer registers combinational rather than clocked | Timer does not advance |
| Hardcoded absolute paths in `init_file` | Breaks on any other machine |
| Address decoder collisions | Multiple peripherals may respond to the same address |

### Roadmap

1. Move the register file and peripheral registers to the rising edge; expect
   a substantial Fmax gain.
2. Implement the performance counters and report IPC across the test suite.
3. Random program generator feeding the co-simulation harness.
4. CI (GitHub Actions + GHDL) running the full suite on every push.
5. Coprocessor 0, `EPC`/`Cause`/`Status`, and proper exceptions.
6. C toolchain: `mips-elf-gcc`, linker script, `crt0`, UART `_write` stub.
