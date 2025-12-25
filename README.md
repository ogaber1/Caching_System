# Cache System Implementation

A 4-way set associative cache system with LRU replacement policy implemented in Verilog HDL.

## Specifications

- **Memory:** 16-bit address, 32-bit data
- **Cache:** 4-way set associative, 256 entries (64 sets × 4 ways)
- **Replacement Policy:** LRU (Least Recently Used)
- **Write Policy:** Write-through

## Files

- `design.v` - Complete system implementation (RAM, Cache, Controller)
- `tb_cache_system.v` - Testbench with 13 test scenarios

## Requirements

- Icarus Verilog (iverilog)
- GTKWave

## How to Run

### Compile
```bash
iverilog -g2012 -o cache_sim design.v tb_cache_system.v
```

### Simulate
```bash
vvp cache_sim
```

### View Waveforms
```bash
gtkwave cache_system.vcd
```

## Viewing Waveforms

In GTKWave, add these signals:

**From `tb_cache_system`:**
- `clk`, `cpu_address`, `cpu_read_enable`, `cpu_write_enable`, `cpu_ready`

**From `tb_cache_system.dut.controller_inst`:**
- `state`, `cache_hit`

**From `tb_cache_system.dut.ram_inst`:**
- `read_enable`, `write_enable`, `ready`

**Key Time Ranges:**
- Cache Miss: 70-150 ns
- Cache Hit: 390-440 ns
- Write Operation: 540-610 ns

## Results

- Cache Miss: 6 cycles
- Cache Hit: 3 cycles
- **Performance Improvement: 50% faster on hits**