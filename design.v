// ============================================================================
// RAM Module - Parameterized Synchronous Memory
// ============================================================================
module RAM #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter MEM_SIZE = 65536  // 2^16
)(
    input wire clk,
    input wire read_enable,
    input wire write_enable,
    input wire [ADDR_WIDTH-1:0] address,
    input wire [DATA_WIDTH-1:0] write_data,
    output reg [DATA_WIDTH-1:0] read_data,
    output reg ready
);

    // Memory array
    reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];
    
    // Initialize memory with some test data
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            memory[i] = i * 10;  // Test pattern
        end
    end
    
    // Synchronous read/write operations
    always @(posedge clk) begin
        ready <= 0;
        
        if (write_enable) begin
            memory[address] <= write_data;
            ready <= 1;
        end
        else if (read_enable) begin
            read_data <= memory[address];
            ready <= 1;
        end
    end

endmodule

// ============================================================================
// Cache Controller with Integrated Cache - Simplified Version
// ============================================================================
module CacheController #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4,
    parameter TAG_WIDTH = 8,
    parameter SET_INDEX_WIDTH = 6,
    parameter OFFSET_WIDTH = 2
)(
    input wire clk,
    input wire rst,
    
    // CPU interface
    input wire [ADDR_WIDTH-1:0] cpu_address,
    input wire [DATA_WIDTH-1:0] cpu_write_data,
    input wire cpu_read_enable,
    input wire cpu_write_enable,
    output reg [DATA_WIDTH-1:0] cpu_read_data,
    output reg cpu_ready,
    
    // RAM interface
    output reg [ADDR_WIDTH-1:0] ram_address,
    output reg [DATA_WIDTH-1:0] ram_write_data,
    output reg ram_read_enable,
    output reg ram_write_enable,
    input wire [DATA_WIDTH-1:0] ram_read_data,
    input wire ram_ready
);

    // Cache storage
    reg [DATA_WIDTH-1:0] cache_data [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [TAG_WIDTH-1:0] cache_tags [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg cache_valid [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [1:0] lru_counter [0:NUM_SETS-1][0:NUM_WAYS-1];
    
    // Address decode registers
    reg [TAG_WIDTH-1:0] tag;
    reg [SET_INDEX_WIDTH-1:0] set_index;
    reg is_read_op;
    reg is_write_op;
    
    // Cache control
    reg cache_hit;
    reg [1:0] hit_way_idx;
    reg [1:0] replace_way_idx;
    
    integer i, j;
    
    // Initialize cache and LRU
    initial begin
        for (i = 0; i < NUM_SETS; i = i + 1) begin
            for (j = 0; j < NUM_WAYS; j = j + 1) begin
                cache_data[i][j] = 0;
                cache_tags[i][j] = 0;
                cache_valid[i][j] = 0;
                lru_counter[i][j] = j[1:0];
            end
        end
    end
    
    // FSM states
    localparam IDLE = 3'd0;
    localparam DECODE = 3'd1;
    localparam CHECK_CACHE = 3'd2;
    localparam RAM_READ = 3'd3;
    localparam UPDATE_CACHE = 3'd4;
    localparam RAM_WRITE = 3'd5;
    localparam COMPLETE = 3'd6;
    
    reg [2:0] state;
    reg waiting_for_ram;
    
    // State machine and cache logic
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cpu_ready <= 0;
            ram_read_enable <= 0;
            ram_write_enable <= 0;
            waiting_for_ram <= 0;
            
            // Clear valid bits
            for (i = 0; i < NUM_SETS; i = i + 1) begin
                for (j = 0; j < NUM_WAYS; j = j + 1) begin
                    cache_valid[i][j] <= 0;
                    lru_counter[i][j] <= j[1:0];
                end
            end
        end
        else begin
            // Default outputs
            cpu_ready <= 0;
            ram_read_enable <= 0;
            ram_write_enable <= 0;
            
            case (state)
                IDLE: begin
                    if (cpu_read_enable || cpu_write_enable) begin
                        // Decode address and capture operation type
                        tag <= cpu_address[ADDR_WIDTH-1:ADDR_WIDTH-TAG_WIDTH];
                        set_index <= cpu_address[ADDR_WIDTH-TAG_WIDTH-1:OFFSET_WIDTH];
                        ram_address <= cpu_address;
                        ram_write_data <= cpu_write_data;
                        is_read_op <= cpu_read_enable;
                        is_write_op <= cpu_write_enable;
                        state <= DECODE;
                    end
                end
                
                DECODE: begin
                    state <= CHECK_CACHE;
                end
                
                CHECK_CACHE: begin
                    // Check all ways for hit
                    cache_hit = 0;
                    hit_way_idx = 0;
                    
                    for (i = 0; i < NUM_WAYS; i = i + 1) begin
                        if (cache_valid[set_index][i] && cache_tags[set_index][i] == tag) begin
                            cache_hit = 1;
                            hit_way_idx = i[1:0];
                        end
                    end
                    
                    // Find replacement way (do this regardless of hit/miss)
                    replace_way_idx = 0;
                    
                    // First check for invalid way
                    for (i = 0; i < NUM_WAYS; i = i + 1) begin
                        if (!cache_valid[set_index][i]) begin
                            replace_way_idx = i[1:0];
                        end
                    end
                    
                    // If all valid, find LRU
                    if (cache_valid[set_index][0] && cache_valid[set_index][1] && 
                        cache_valid[set_index][2] && cache_valid[set_index][3]) begin
                        for (i = 0; i < NUM_WAYS; i = i + 1) begin
                            if (lru_counter[set_index][i] == 0) begin
                                replace_way_idx = i[1:0];
                            end
                        end
                    end
                    
                    if (cache_hit) begin
                        // Cache hit
                        cpu_read_data <= cache_data[set_index][hit_way_idx];
                        
                        // Update LRU
                        lru_counter[set_index][hit_way_idx] <= 3;
                        for (i = 0; i < NUM_WAYS; i = i + 1) begin
                            if (i != hit_way_idx && lru_counter[set_index][i] > 0) begin
                                lru_counter[set_index][i] <= lru_counter[set_index][i] - 1;
                            end
                        end
                        
                        if (is_write_op) begin
                            // Write hit - update cache and write through to RAM
                            cache_data[set_index][hit_way_idx] <= cpu_write_data;
                            ram_write_enable <= 1;
                            waiting_for_ram <= 1;
                            state <= RAM_WRITE;
                        end
                        else begin
                            // Read hit - done
                            state <= COMPLETE;
                        end
                    end
                    else begin
                        // Cache miss
                        if (is_read_op) begin
                            // Read miss - fetch from RAM
                            ram_read_enable <= 1;
                            waiting_for_ram <= 1;
                            state <= RAM_READ;
                        end
                        else begin
                            // Write miss - write to RAM only (no cache allocation on write miss)
                            ram_write_enable <= 1;
                            waiting_for_ram <= 1;
                            state <= RAM_WRITE;
                        end
                    end
                end
                
                RAM_READ: begin
                    if (waiting_for_ram) begin
                        ram_read_enable <= 1;
                        if (ram_ready) begin
                            waiting_for_ram <= 0;
                            state <= UPDATE_CACHE;
                        end
                    end
                end
                
                UPDATE_CACHE: begin
                    // Update cache with data from RAM
                    cache_data[set_index][replace_way_idx] <= ram_read_data;
                    cache_tags[set_index][replace_way_idx] <= tag;
                    cache_valid[set_index][replace_way_idx] <= 1;
                    cpu_read_data <= ram_read_data;
                    
                    // Update LRU
                    lru_counter[set_index][replace_way_idx] <= 3;
                    for (i = 0; i < NUM_WAYS; i = i + 1) begin
                        if (i != replace_way_idx && lru_counter[set_index][i] > 0) begin
                            lru_counter[set_index][i] <= lru_counter[set_index][i] - 1;
                        end
                    end
                    
                    state <= COMPLETE;
                end
                
                RAM_WRITE: begin
                    if (waiting_for_ram) begin
                        ram_write_enable <= 1;
                        if (ram_ready) begin
                            waiting_for_ram <= 0;
                            state <= COMPLETE;
                        end
                    end
                end
                
                COMPLETE: begin
                    cpu_ready <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// ============================================================================
// Top-Level Module - Complete Cache System
// ============================================================================
module CacheSystem #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter NUM_SETS = 64,
    parameter NUM_WAYS = 4
)(
    input wire clk,
    input wire rst,
    
    // CPU interface
    input wire [ADDR_WIDTH-1:0] cpu_address,
    input wire [DATA_WIDTH-1:0] cpu_write_data,
    input wire cpu_read_enable,
    input wire cpu_write_enable,
    output wire [DATA_WIDTH-1:0] cpu_read_data,
    output wire cpu_ready
);

    // Internal signals
    wire [ADDR_WIDTH-1:0] ram_address;
    wire [DATA_WIDTH-1:0] ram_write_data;
    wire ram_read_enable;
    wire ram_write_enable;
    wire [DATA_WIDTH-1:0] ram_read_data;
    wire ram_ready;
    
    // Instantiate RAM
    RAM #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) ram_inst (
        .clk(clk),
        .read_enable(ram_read_enable),
        .write_enable(ram_write_enable),
        .address(ram_address),
        .write_data(ram_write_data),
        .read_data(ram_read_data),
        .ready(ram_ready)
    );
    
    // Instantiate Cache Controller
    CacheController #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) controller_inst (
        .clk(clk),
        .rst(rst),
        .cpu_address(cpu_address),
        .cpu_write_data(cpu_write_data),
        .cpu_read_enable(cpu_read_enable),
        .cpu_write_enable(cpu_write_enable),
        .cpu_read_data(cpu_read_data),
        .cpu_ready(cpu_ready),
        .ram_address(ram_address),
        .ram_write_data(ram_write_data),
        .ram_read_enable(ram_read_enable),
        .ram_write_enable(ram_write_enable),
        .ram_read_data(ram_read_data),
        .ram_ready(ram_ready)
    );

endmodule