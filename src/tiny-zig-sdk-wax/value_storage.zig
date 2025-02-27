const std = @import("std");
const utils = @import("utils.zig");
const hostio = @import("hostio.zig");
pub const Address: type = [20]u8;

const AddressUtils = utils.AddressUtils;
const U256Utils = utils.U256Utils;

// This list is the state varibles what we support now for user to declare on contracts.
pub const SolStorageType = enum { U256Storage, BoolStorage, AddressStorage, Bytes32Storage, MappingStorage, VecStorage };

pub const U256Storage = struct {
    offset: [32]u8,
    cache: []u8,
    const inner_type: type = u256;

    pub fn init(offset_value: [32]u8) @This() {
        return .{
            .offset = offset_value,
            .cache = undefined,
        };
    }

    pub fn set_value(self: *@This(), value: u256) !void {
        const offset_bytes = try utils.bytes32_to_bytes(self.offset);
        const value_bytes = try utils.u256_to_bytes(value);
        try hostio.write_storage(offset_bytes, value_bytes);
        self.cache = value_bytes;
    }

    pub fn get_value(self: *@This()) !u256 {
        if (utils.is_slice_undefined(self.cache)) {
            const offset_bytes = try utils.bytes32_to_bytes(self.offset);
            self.cache = try hostio.read_storage(offset_bytes);
        }
        return utils.bytes_to_u256(self.cache);
    }
};

pub const BoolStorage = struct {
    offset: [32]u8,
    cache: []u8,
    const inner_type: type = bool;

    pub fn init(offset_value: [32]u8) @This() {
        return .{
            .offset = offset_value,
            .cache = undefined,
        };
    }

    pub fn set_value(self: *@This(), value: bool) !void {
        const offset_bytes = try utils.bytes32ToBytes(self.offset);
        const value_bytes = try utils.bool_to_bytes(value);
        try hostio.write_storage(offset_bytes, value_bytes);
        self.cache = value_bytes;
    }

    pub fn get_value(self: *@This()) !bool {
        if (utils.is_slice_undefined(self.cache)) {
            const offset_bytes = try utils.bytes32ToBytes(self.offset);
            self.cache = try hostio.read_storage(offset_bytes);
        }
        return utils.bytesToBool(self.cache);
    }
};

pub const AddressStorage = struct {
    offset: [32]u8,
    cache: []u8,
    const inner_type: type = Address;

    pub fn init(offset_value: [32]u8) @This() {
        return .{
            .offset = offset_value,
            .cache = undefined,
        };
    }

    pub fn set_value(self: *@This(), value: Address) !void {
        const offset_bytes = try utils.bytes32_to_bytes(self.offset);
        const address_bytes = try utils.address_to_bytes(value);
        try hostio.write_storage(offset_bytes, address_bytes);
        self.cache = address_bytes;
    }

    pub fn get_value(self: *@This()) !Address {
        if (utils.is_slice_undefined(self.cache)) {
            const offset_bytes = try utils.bytes32_to_bytes(self.offset);
            self.cache = try hostio.read_storage(offset_bytes);
        }
        const result = utils.bytes_to_address(self.cache);
        return result;
    }
};

pub const Bytes32Storage = struct {
    offset: [32]u8,
    cache: []u8,
    const inner_type: type = [32]u8;

    pub fn init(offset_value: [32]u8) @This() {
        return .{
            .offset = offset_value,
            .cache = undefined,
        };
    }

    pub fn set_value(self: *@This(), value: [32]u8) !void {
        const offset_bytes = try utils.bytes32ToBytes(self.offset);
        const value_bytes = try utils.bytes32ToBytes(value);
        try hostio.write_storage(offset_bytes, value_bytes);
        self.cache = value_bytes;
    }

    pub fn get_value(self: *@This()) ![32]u8 {
        if (utils.is_slice_undefined(self.cache)) {
            const offset_bytes = try utils.bytes32ToBytes(self.offset);
            self.cache = try hostio.read_storage(offset_bytes);
        }
        var result: [32]u8 = undefined;
        std.mem.copyForwards(u8, &result, self.cache);
        return result;
    }
};

pub fn MappingStorage(comptime KeyType: type, comptime ValueStorageType: type) type {
    const value_inner_type: type = ValueStorageType.inner_type;
    const key_utils = utils.get_value_utils(KeyType);
    const value_utils = utils.get_value_utils(value_inner_type);
    const converter_type = struct {
        key_utils: key_utils,
        value_utils: value_utils,
    };

    return struct {
        offset: [32]u8,
        converter: converter_type,
        const inner_type: type = @TypeOf(@This());
        const ValueInnerType: type = value_inner_type;

        pub fn init(offset: [32]u8) @This() {
            return .{ .offset = offset, .converter = .{
                .key_utils = key_utils{},
                .value_utils = value_utils{},
            } };
        }

        fn compute_mapping_slot(slot: [32]u8, key: []const u8) ![32]u8 {
            var concat = try utils.allocator.alloc(u8, 32 + key.len);
            defer utils.allocator.free(concat);

            std.mem.copyForwards(u8, concat[0..32], &slot);
            std.mem.copyForwards(u8, concat[32..], key);

            return hostio.keccak256(concat);
        }

        pub fn setter(self: *@This(), key: KeyType) !ValueStorageType {
            const key_bytes = try self.converter.key_utils.to_bytes(key);
            const slot_key_offset = try compute_mapping_slot(self.offset, key_bytes);
            const result = ValueStorageType.init(slot_key_offset);
            return result;
        }

        // if it is nested mapping, this can't be called.
        pub fn get(self: *@This(), key: KeyType) !ValueInnerType {
            const key_bytes = try self.converter.key_utils.to_bytes(key);
            const slot_key_offset = try compute_mapping_slot(self.offset, key_bytes);
            var storage_helper = ValueStorageType.init(slot_key_offset);
            const result = storage_helper.get_value();
            return result;
        }

        // This will only be called when mapping is nested. (deprecated now)
        pub fn get_value(self: *@This()) !ValueInnerType {
            return self;
        }
    };
}

pub fn VecStorage(comptime ElementStorageType: type) type {
    const element_inner_type = ElementStorageType.inner_type;

    return struct {
        offset: [32]u8,
        length_storage: U256Storage,
        const inner_type: type = []element_inner_type;

        pub fn init(offset_value: [32]u8) @This() {
            return .{
                .offset = offset_value,
                .length_storage = U256Storage.init(offset_value),
            };
        }

        fn compute_array_slot(slot: [32]u8, index: u256) ![32]u8 {
            const index_bytes = try utils.u256_to_bytes(index);
            var concat = try utils.allocator.alloc(u8, 64);
            defer utils.allocator.free(concat);

            std.mem.copyForwards(u8, concat[0..32], &slot);
            std.mem.copyForwards(u8, concat[32..], index_bytes);

            return try hostio.keccak256(concat);
        }

        pub fn length(self: *@This()) !u256 {
            return try self.length_storage.get_value();
        }

        pub fn push(self: *@This(), value: element_inner_type) !void {
            const len = try self.length();
            // Update length
            try self.length_storage.set_value(len + 1);

            // Store new element using element storage helper
            const slot = try compute_array_slot(self.offset, len);
            var element_storage = ElementStorageType.init(slot);
            try element_storage.set_value(value);
        }

        pub fn get(self: *@This(), index: u256) !element_inner_type {
            const len = try self.length();
            if (index >= len) return error.IndexOutOfBounds;

            const slot = try compute_array_slot(self.offset, index);
            var element_storage = ElementStorageType.init(slot);
            return try element_storage.get_value();
        }

        pub fn set(self: *@This(), index: u256, value: element_inner_type) !void {
            const len = try self.length();
            if (index >= len) return error.IndexOutOfBounds;

            const slot = try compute_array_slot(self.offset, index);
            var element_storage = ElementStorageType.init(slot);
            try element_storage.set_value(value);
        }
    };
}

// Define mixin for shared initialization behavior
pub fn SolStorage(comptime Self: type) type {
    return struct {
        pub fn init() Self {
            var result: Self = undefined;
            comptime var offset: u32 = 0;
            inline for (std.meta.fields(Self)) |field| {
                @field(result, field.name) = switch (field.type) {
                    U256Storage => field.type.init(utils.u32_to_bytes32(offset)),
                    AddressStorage => field.type.init(utils.u32_to_bytes32(offset)),
                    BoolStorage => field.type.init(utils.u32_to_bytes32(offset)),
                    Bytes32Storage => field.type.init(utils.u32_to_bytes32(offset)),
                    // Todo, support edge case.
                    else => blk: {
                        @setEvalBranchQuota(100000);
                        const type_name = @typeName(field.type);
                        // @compileLog("type_name: {}", .{type_name});
                        if (std.mem.indexOf(u8, type_name, "MappingStorage") != null) {
                            const offset_bytes = utils.u32_to_bytes32(offset);
                            break :blk field.type.init(offset_bytes);
                        } else if (std.mem.indexOf(u8, type_name, "VecStorage") != null) {
                            const offset_bytes = utils.u32_to_bytes32(offset);
                            break :blk field.type.init(offset_bytes);
                        } else if (std.mem.indexOf(u8, type_name, "EventEmitter") != null) {
                            break :blk .{}; // Initialize event with empty struct
                        } else {
                            @compileError("Unsupported Solidity type: " ++ type_name);
                        }
                    },
                };
                offset += 1;
            }
            return result;
        }
    };
}
