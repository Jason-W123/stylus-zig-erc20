const std = @import("std");
const WasmAllocator = @import("WasmAllocator.zig");
const zabi = @import("zabi");
const decoder = zabi.decoding.abi_decoder;

pub extern "vm_hooks" fn read_args(dest: *u8) void;
pub extern "vm_hooks" fn write_result(data: *const u8, len: usize) void;
pub extern "vm_hooks" fn storage_cache_bytes32(key: *const u8, value: *const u8) void;
pub extern "vm_hooks" fn block_number() u64;
pub extern "vm_hooks" fn storage_flush_cache(clear: bool) void;
pub extern "vm_hooks" fn native_keccak256(bytes: *const u8, len: usize, output: *u8) void;

// Standard ERC20 function selectors (first 4 bytes of keccak256 hash of function signatures)
const TOTAL_SUPPLY_SELECTOR = [_]u8{ 0x18, 0x16, 0x0d, 0xdd }; // totalSupply()
const BALANCE_OF_SELECTOR = [_]u8{ 0x70, 0xa0, 0x82, 0x31 }; // balanceOf(address)
const TRANSFER_SELECTOR = [_]u8{ 0xa9, 0x05, 0x9c, 0xbb }; // transfer(address,uint256)
const ALLOWANCE_SELECTOR = [_]u8{ 0xdd, 0x62, 0xed, 0x3e }; // allowance(address,address)
const APPROVE_SELECTOR = [_]u8{ 0x09, 0x5e, 0xa7, 0xb3 }; // approve(address,uint256)
const TRANSFER_FROM_SELECTOR = [_]u8{ 0x23, 0xb8, 0x72, 0xdd }; // transferFrom(address,address,uint256)

// Storage slots
pub const SLOTS = struct {
    pub const NAME = 0;
    pub const SYMBOL = 1;
    pub const DECIMALS = 2;
    pub const TOTAL_SUPPLY = 3;
    pub const BALANCES = 4;
    pub const ALLOWANCES = 5;
};

// Uses our custom WasmAllocator which is a simple modification over the wasm allocator
// from the Zig standard library as of Zig 0.11.0.
pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &WasmAllocator.vtable,
};

// Reads input arguments from an external, WASM import into a dynamic slice.
pub fn get_input(len: usize) ![]u8 {
    const input = try allocator.alloc(u8, len);
    read_args(@ptrCast(input));
    return input;
}

// Outputs data as bytes via a write_result, external WASM import.
pub fn write_output(data: []u8) void {
    write_result(@ptrCast(data), data.len);
}

pub fn write_storage(key: []u8, value: []u8) void {
    storage_cache_bytes32(@ptrCast(key), @ptrCast(value));
    storage_flush_cache(true);
}

pub fn router_method(selector: [4]u8) void {
    switch (@as(u32, selector[0]) << 24 | @as(u32, selector[1]) << 16 | @as(u32, selector[2]) << 8 | @as(u32, selector[3])) {
        @as(u32, TOTAL_SUPPLY_SELECTOR[0]) << 24 | @as(u32, TOTAL_SUPPLY_SELECTOR[1]) << 16 | @as(u32, TOTAL_SUPPLY_SELECTOR[2]) << 8 | @as(u32, TOTAL_SUPPLY_SELECTOR[3]) => {
            // try stdout.print("totalSupply called\n", .{});
            // Add totalSupply logic here
        },
        @as(u32, BALANCE_OF_SELECTOR[0]) << 24 | @as(u32, BALANCE_OF_SELECTOR[1]) << 16 | @as(u32, BALANCE_OF_SELECTOR[2]) << 8 | @as(u32, BALANCE_OF_SELECTOR[3]) => {
            // const decoded = try decoder.decodeAbiFunction([20]u8, allocator, encoded, .{});
            // try stdout.print("balanceOf called for address: 0x{}\n", .{std.fmt.fmtSliceHexLower(&decoded.result)});
            // Add balanceOf logic here
        },
        @as(u32, TRANSFER_SELECTOR[0]) << 24 | @as(u32, TRANSFER_SELECTOR[1]) << 16 | @as(u32, TRANSFER_SELECTOR[2]) << 8 | @as(u32, TRANSFER_SELECTOR[3]) => {
            // try stdout.print("transfer called\n", .{});
            // Add transfer logic here
        },
        @as(u32, ALLOWANCE_SELECTOR[0]) << 24 | @as(u32, ALLOWANCE_SELECTOR[1]) << 16 | @as(u32, ALLOWANCE_SELECTOR[2]) << 8 | @as(u32, ALLOWANCE_SELECTOR[3]) => {
            // try stdout.print("allowance called\n", .{});
            // Add allowance logic here
        },
        @as(u32, APPROVE_SELECTOR[0]) << 24 | @as(u32, APPROVE_SELECTOR[1]) << 16 | @as(u32, APPROVE_SELECTOR[2]) << 8 | @as(u32, APPROVE_SELECTOR[3]) => {
            // try stdout.print("approve called\n", .{});
            // Add approve logic here
        },
        @as(u32, TRANSFER_FROM_SELECTOR[0]) << 24 | @as(u32, TRANSFER_FROM_SELECTOR[1]) << 16 | @as(u32, TRANSFER_FROM_SELECTOR[2]) << 8 | @as(u32, TRANSFER_FROM_SELECTOR[3]) => {
            // try stdout.print("transferFrom called\n", .{});
            // Add transferFrom logic here
        },
        else => {
            // try stdout.print("Unknown function selector\n", .{});
        },
    }
}

pub fn keccak256(data: []u8) ![]u8 {
    const output = try allocator.alloc(u8, 32);
    native_keccak256(@ptrCast(data), data.len, @ptrCast(output));
    return output;
}

pub fn compute_mapping_slot(key: []const u8, slot: u256) []u8 {
    var concat: [64]u8 = undefined;
    std.mem.copy(u8, concat[0..32], key);
    std.mem.copy(u8, concat[32..64], &slot);
    return keccak256(concat[0..]);
}
