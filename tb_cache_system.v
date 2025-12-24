`timescale 1ns/1ps

module tb_cache_system;

    // Parameters
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 32;
    parameter NUM_SETS = 64;
    parameter NUM_WAYS = 4;
    parameter CLK_PERIOD = 10;
    
    // Signals
    reg clk;
    reg rst;
    reg [ADDR_WIDTH-1:0] cpu_address;
    reg [DATA_WIDTH-1:0] cpu_write_data;
    reg cpu_read_enable;
    reg cpu_write_enable;
    wire [DATA_WIDTH-1:0] cpu_read_data;
    wire cpu_ready;
    
    // Statistics
    integer total_reads = 0;
    integer total_writes = 0;
    integer cache_hits = 0;
    integer cache_misses = 0;
    
    // Instantiate the cache system
    CacheSystem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .cpu_address(cpu_address),
        .cpu_write_data(cpu_write_data),
        .cpu_read_enable(cpu_read_enable),
        .cpu_write_enable(cpu_write_enable),
        .cpu_read_data(cpu_read_data),
        .cpu_ready(cpu_ready)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task to perform read operation
    task read_memory(input [ADDR_WIDTH-1:0] addr);
        begin
            @(posedge clk);
            cpu_address = addr;
            cpu_read_enable = 1;
            cpu_write_enable = 0;
            total_reads = total_reads + 1;
            
            @(posedge clk);
            cpu_read_enable = 0;
            
            // Wait for operation to complete
            wait(cpu_ready);
            @(posedge clk);
            
            $display("Time=%0t | READ  | Addr=0x%04h | Data=0x%08h", 
                     $time, addr, cpu_read_data);
        end
    endtask
    
    // Task to perform write operation
    task write_memory(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            cpu_address = addr;
            cpu_write_data = data;
            cpu_read_enable = 0;
            cpu_write_enable = 1;
            total_writes = total_writes + 1;
            
            @(posedge clk);
            cpu_write_enable = 0;
            
            // Wait for operation to complete
            wait(cpu_ready);
            @(posedge clk);
            
            $display("Time=%0t | WRITE | Addr=0x%04h | Data=0x%08h", 
                     $time, addr, data);
        end
    endtask
    
    // Test stimulus
    initial begin
        // Initialize waveform dump
        $dumpfile("cache_system.vcd");
        $dumpvars(0, tb_cache_system);
        
        // Initialize signals
        rst = 1;
        cpu_address = 0;
        cpu_write_data = 0;
        cpu_read_enable = 0;
        cpu_write_enable = 0;
        
        // Reset
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);
        
        $display("\n========================================");
        $display("Starting Cache System Test");
        $display("========================================\n");
        
        // Test 1: Simple read (cache miss - first access)
        $display("--- Test 1: Initial Reads (Cache Misses) ---");
        read_memory(16'h0000);
        read_memory(16'h0004);
        read_memory(16'h0008);
        read_memory(16'h000C);
        
        // Test 2: Read same addresses (cache hits)
        $display("\n--- Test 2: Repeated Reads (Cache Hits) ---");
        read_memory(16'h0000);
        read_memory(16'h0004);
        read_memory(16'h0008);
        
        // Test 3: Write operations
        $display("\n--- Test 3: Write Operations ---");
        write_memory(16'h0100, 32'hDEADBEEF);
        write_memory(16'h0104, 32'hCAFEBABE);
        write_memory(16'h0108, 32'h12345678);
        
        // Test 4: Read back written data (should be cache hits)
        $display("\n--- Test 4: Read Back Written Data ---");
        read_memory(16'h0100);
        read_memory(16'h0104);
        read_memory(16'h0108);
        
        // Test 5: Test same set, different tags (to test associativity)
        $display("\n--- Test 5: Testing 4-Way Associativity ---");
        // These addresses map to the same set but different tags
        read_memory(16'h0010);  // Set 4, Tag 0
        read_memory(16'h0410);  // Set 4, Tag 1
        read_memory(16'h0810);  // Set 4, Tag 2
        read_memory(16'h0C10);  // Set 4, Tag 3
        
        // Test 6: Read them again (all should be cache hits)
        $display("\n--- Test 6: Read Same Set (Cache Hits) ---");
        read_memory(16'h0010);
        read_memory(16'h0410);
        read_memory(16'h0810);
        read_memory(16'h0C10);
        
        // Test 7: Force a replacement (5th way in same set)
        $display("\n--- Test 7: Testing LRU Replacement ---");
        read_memory(16'h1010);  // Set 4, Tag 4 - should replace LRU
        
        // Test 8: Sequential access pattern
        $display("\n--- Test 8: Sequential Access Pattern ---");
        read_memory(16'h0200);
        read_memory(16'h0204);
        read_memory(16'h0208);
        read_memory(16'h020C);
        read_memory(16'h0210);
        
        // Test 9: Write and read back immediately
        $display("\n--- Test 9: Write-Through Verification ---");
        write_memory(16'h0300, 32'hA5A5A5A5);
        read_memory(16'h0300);
        
        // Test 10: Random access pattern
        $display("\n--- Test 10: Random Access Pattern ---");
        read_memory(16'h1234);
        read_memory(16'h5678);
        read_memory(16'h9ABC);
        read_memory(16'hDEF0);
        
        // Test 11: Burst write
        $display("\n--- Test 11: Burst Write Operations ---");
        write_memory(16'h0500, 32'h11111111);
        write_memory(16'h0504, 32'h22222222);
        write_memory(16'h0508, 32'h33333333);
        write_memory(16'h050C, 32'h44444444);
        
        // Test 12: Burst read
        $display("\n--- Test 12: Burst Read Operations ---");
        read_memory(16'h0500);
        read_memory(16'h0504);
        read_memory(16'h0508);
        read_memory(16'h050C);
        
        // Test 13: Test conflict scenario
        $display("\n--- Test 13: Cache Conflict Scenario ---");
        // Fill up all ways in a set
        write_memory(16'h0020, 32'hAAAAAAAA);
        write_memory(16'h0420, 32'hBBBBBBBB);
        write_memory(16'h0820, 32'hCCCCCCCC);
        write_memory(16'h0C20, 32'hDDDDDDDD);
        
        // Access them to establish LRU order
        read_memory(16'h0020);
        read_memory(16'h0420);
        read_memory(16'h0820);
        read_memory(16'h0C20);
        
        // Add 5th element - should evict 0x0020 (LRU)
        write_memory(16'h1020, 32'hEEEEEEEE);
        read_memory(16'h1020);
        
        // Try to read evicted address (should be miss and reload)
        read_memory(16'h0020);
        
        // Wait some time
        repeat(10) @(posedge clk);
        
        // Print statistics
        $display("\n========================================");
        $display("Test Complete - Statistics");
        $display("========================================");
        $display("Total Reads:  %0d", total_reads);
        $display("Total Writes: %0d", total_writes);
        $display("Total Operations: %0d", total_reads + total_writes);
        $display("========================================\n");
        
        // Finish simulation
        $display("Simulation completed successfully!");
        #100;
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("Time=%0t | State=%0d | Addr=0x%04h | Ready=%b | Hit=%b", 
                 $time, dut.controller_inst.state, cpu_address, cpu_ready,
                 dut.controller_inst.cache_hit);
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule