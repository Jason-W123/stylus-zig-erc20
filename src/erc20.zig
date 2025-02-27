const std = @import("std");
const utils = @import("./tiny-zig-sdk-wax/utils.zig");
const hostio = @import("./tiny-zig-sdk-wax/hostio.zig");
const ValueStorage = @import("./tiny-zig-sdk-wax/value_storage.zig");
const EventUtils = @import("./tiny-zig-sdk-wax/event.zig");
const U256Storage = ValueStorage.U256Storage;
const AddressStorage = ValueStorage.AddressStorage;
const MappingStorage = ValueStorage.MappingStorage;
const SolStorage = ValueStorage.SolStorage;
const VecStorage = ValueStorage.VecStorage;
const EventEmitter = EventUtils.EventEmitter;
const Indexed = EventUtils.Indexed;
const Address = ValueStorage.Address;

pub const ERC20 = struct {
    pub usingnamespace SolStorage(@This());

    // Define constant value here
    const DECIMALS: u8 = 18;

    // Define state here
    _total_supply: U256Storage,
    _owner: AddressStorage,
    _balances: MappingStorage(Address, U256Storage),
    _allowances: MappingStorage(Address, MappingStorage(Address, U256Storage)),

    // Define event with EventEmitter
    Transfer: EventEmitter("Transfer", struct {
        Indexed(Address), // Indexed data: from
        Indexed(Address), // Indexed data: to
        u256, // Unindexed data: amount
    }),
    Approval: EventEmitter("Approval", struct {
        Indexed(Address), // Indexed data: owner
        Indexed(Address), // Indexed data: spender
        u256, // Unindexed data: amount
    }),
    Initiated: EventEmitter("Initiated", struct {
        Address, // Unindexed data: sender
        u256, // Unindexed data: amount
    }),

    // Define function here
    pub fn decimals(_: *@This()) u8 {
        return DECIMALS;
    }

    pub fn initiate(self: *@This(), _supply: u256) !void {
        // First, check if it is already initiated
        const old_owner = try self.owner();
        const address_utils = utils.AddressUtils{};
        if (!address_utils.is_zero_address(old_owner)) {
            @panic("Already initiated");
        }

        // Set owner, and mint total_supply number of tokens to the owner
        const sender = try hostio.get_msg_sender();
        try self._total_supply.set_value(_supply);
        try self._owner.set_value(sender);
        var balances_setter = try self._balances.setter(sender);
        try balances_setter.set_value(_supply);
        const block_number = hostio.get_block_number();

        // emit initiated event
        try self.Initiated.emit(.{
            sender,
            block_number,
        });
    }

    pub fn owner(self: *@This()) !Address {
        const value = try self._owner.get_value();

        return value;
    }

    pub fn total_supply(self: *@This()) ![]u8 {
        const value = try self._total_supply.get_value();

        return utils.u256_to_bytes(value);
    }

    pub fn balanceOf(self: *@This(), address: Address) !u256 {
        const balance = try self._balances.get(address);

        return balance;
    }

    fn _transfer(self: *@This(), from: Address, to: Address, value: u256) !bool {
        const from_balance = try self._balances.get(from);
        const to_balance = try self._balances.get(to);
        if (from_balance < value) {
            return false;
        }

        // Calculate new balances
        const new_from_balance = from_balance - value;
        const new_to_balance = to_balance + value;

        // Update balances
        var from_balances_setter = try self._balances.setter(from);
        var to_balances_setter = try self._balances.setter(to);
        try from_balances_setter.set_value(new_from_balance);
        try to_balances_setter.set_value(new_to_balance);

        // Emit Transfer event
        try self.Transfer.emit(.{
            Indexed(Address){ .value = from },
            Indexed(Address){ .value = to },
            value,
        });
        return true;
    }

    pub fn transfer(self: *@This(), to: Address, value: u256) !bool {
        const sender = try hostio.get_msg_sender();
        return try _transfer(self, sender, to, value);
    }

    pub fn transferFrom(self: *@This(), from: Address, to: Address, value: u256) !bool {
        const msg_sender = try hostio.get_msg_sender();
        // Get value from allowances, this is nested mapping, so needs to call twice setter
        var from_allowance_map = try self._allowances.setter(from);
        var from_sender_allowance = try from_allowance_map.setter(msg_sender);
        // Finally get the storage and then set the value
        const old_from_to_allowance = try from_sender_allowance.get_value();
        if (old_from_to_allowance < value) {
            return false;
        }
        // Calculate new allowance
        const new_from_to_allowance = old_from_to_allowance - value;
        // Update allowance
        try from_sender_allowance.set_value(new_from_to_allowance);
        return try self._transfer(from, to, value);
    }

    pub fn approve(self: *@This(), spender: Address, value: u256) !bool {
        const sender = try hostio.get_msg_sender();
        const sender_balance = try self._balances.get(sender);

        if (sender_balance < value) {
            return false;
        }

        var sender_allowance_map = try self._allowances.setter(sender);
        var sender_spender_allowance = try sender_allowance_map.setter(spender);

        try sender_spender_allowance.set_value(value);
        // emit Approval event
        try self.Approval.emit(.{
            Indexed(Address){ .value = sender },
            Indexed(Address){ .value = spender },
            value,
        });
        return true;
    }

    pub fn allowance(self: *@This(), owner_addr: Address, spender: Address) !u256 {
        var owner_allowance_map = try self._allowances.setter(owner_addr);
        var sender_spender_allowance = try owner_allowance_map.setter(spender);
        const sender_spender_allowance_value = try sender_spender_allowance.get_value();
        return sender_spender_allowance_value;
    }
};
