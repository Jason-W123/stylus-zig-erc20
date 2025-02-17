const std = @import("std");
const utils = @import("utils.zig");
const ValueStorage = @import("value_storage.zig");
const EventUtils = @import("event.zig");
const U256Storage = ValueStorage.U256Storage;
const AddressStorage = ValueStorage.AddressStorage;
const MappingStorage = ValueStorage.MappingStorage;
const SolStorage = ValueStorage.SolStorage;
const EventEmitter = EventUtils.EventEmitter;
const Indexed = EventUtils.Indexed;
const Address = ValueStorage.Address;

pub const ERC20 = struct {
    pub usingnamespace SolStorage(@This());

    // Define constant value here
    const DECIMALS: u8 = 18;

    // Define state here
    total_supply: U256Storage,
    _owner: AddressStorage,
    balances: MappingStorage(Address, U256Storage),
    allowances: MappingStorage(Address, MappingStorage(Address, U256Storage)),

    // Define event with EventEmitter
    Transfer: EventEmitter("Transfer", struct {
        Indexed(Address), // Indexed data
        Indexed(Address), // Indexed data
        u256, // Unindexed data
    }),
    Approval: EventEmitter("Approval", struct {
        Indexed(Address), // Indexed data
        Indexed(Address), // Indexed data
        u256, // Unindexed data
    }),

    pub fn decimals(_: *@This()) u8 {
        return DECIMALS;
    }

    pub fn initiate(self: *@This(), total_supply: u256) !void {
        // First, check if it is already initiated
        const old_owner = try self.owner();
        const address_utils = utils.AddressUtils{};
        if (!address_utils.is_zero_address(old_owner)) {
            @panic("Already initiated");
        }

        // Set owner, and mint total_supply number of tokens to the owner
        const sender = try utils.get_msg_sender();
        try self.total_supply.set_value(total_supply);
        try self._owner.set_value(sender);
        var balances_setter = try self.balances.setter(sender);
        try balances_setter.set_value(total_supply);
    }

    pub fn owner(self: *@This()) !Address {
        const value = try self._owner.get_value();

        return value;
    }

    pub fn totalSupply(self: *@This()) ![]u8 {
        const value = try self.total_supply.get_value();

        return utils.u256ToBytes(value);
    }

    pub fn balanceOf(self: *@This(), address: Address) !u256 {
        const balance = try self.balances.get(address);

        return balance;
    }

    fn _transfer(self: *@This(), from: Address, to: Address, value: u256) !bool {
        const from_balance = try self.balances.get(from);
        const to_balance = try self.balances.get(to);
        if (from_balance < value) {
            return false;
        }

        // Calculate new balances
        const new_from_balance = from_balance - value;
        const new_to_balance = to_balance + value;

        // Update balances
        var from_balances_setter = try self.balances.setter(from);
        var to_balances_setter = try self.balances.setter(to);
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
        const sender = try utils.get_msg_sender();
        return try _transfer(self, sender, to, value);
    }

    pub fn transferFrom(self: *@This(), from: Address, to: Address, value: u256) !bool {
        const msg_sender = try utils.get_msg_sender();
        // Get value from allowances, this is nested mapping, so needs to call twice setter
        var from_allowance_map = try self.allowances.setter(from);
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
        const sender = try utils.get_msg_sender();
        const sender_balance = try self.balances.get(sender);

        var sender_allowance_map = try self.allowances.setter(sender);
        var sender_spender_allowance = try sender_allowance_map.setter(spender);

        const sender_spender_allowance_value = try sender_spender_allowance.get_value();
        if (sender_balance < value) {
            return false;
        }
        const new_sender_allowance = sender_spender_allowance_value + value;
        try sender_spender_allowance.set_value(new_sender_allowance);
        // emit Approval event
        try self.Approval.emit(.{
            Indexed(Address){ .value = sender },
            Indexed(Address){ .value = spender },
            value,
        });
        return true;
    }

    pub fn allowance(self: *@This(), owner_addr: Address, spender: Address) !u256 {
        var owner_allowance_map = try self.allowances.setter(owner_addr);
        var sender_spender_allowance = try owner_allowance_map.setter(spender);
        const sender_spender_allowance_value = try sender_spender_allowance.get_value();
        return sender_spender_allowance_value;
    }
};
