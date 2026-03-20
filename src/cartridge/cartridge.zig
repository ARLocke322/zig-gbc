const MBC0 = @import("MBC0.zig").MBC0;
const MBC1 = @import("MBC1.zig").MBC1;
const MBC2 = @import("MBC2.zig").MBC2;
const MBC3 = @import("MBC3.zig").MBC3;
const MBC5 = @import("MBC5.zig").MBC5;
const std = @import("std");

pub const Cartridge = struct {
    mbc: MBC,
    cgb: bool,
    allocator: std.mem.Allocator,

    pub const MBC = union(enum) {
        mbc0: MBC0,
        mbc1: MBC1,
        mbc2: MBC2,
        mbc3: MBC3,
        mbc5: MBC5,
    };

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !Cartridge {
        const ram_size: usize = getRamSize(data[0x149]);
        const cgb_flag = data[0x143];
        const cgb: bool = cgb_flag == 0x80 or cgb_flag == 0xC0;

        const mbc: MBC = switch (data[0x147]) {
            0x00 => .{ .mbc0 = try MBC0.init(allocator, data, ram_size) },
            0x01...0x03 => .{ .mbc1 = try MBC1.init(allocator, data, ram_size) },
            0x05...0x06 => .{ .mbc2 = try MBC2.init(allocator, data, ram_size) },
            0x0F...0x13 => .{ .mbc3 = try MBC3.init(allocator, data, ram_size) },
            0x19...0x1E => .{ .mbc5 = try MBC5.init(allocator, data, ram_size) },
            else => return error.UnimplementedCartridge,
        };

        return .{ .mbc = mbc, .cgb = cgb, .allocator = allocator };
    }
    pub fn read(self: *Cartridge, address: u16) u8 {
        return switch (self.mbc) {
            inline else => |*mbc| mbc.read(address),
        };
    }
    pub fn write(self: *Cartridge, address: u16, value: u8) void {
        switch (self.mbc) {
            inline else => |*mbc| mbc.write(address, value),
        }
    }
    pub fn save(self: *Cartridge) []u8 {
        return switch (self.mbc) {
            inline else => |*mbc| mbc.save(),
        };
    }
    pub fn load(self: *Cartridge, save_data: []u8) void {
        switch (self.mbc) {
            inline else => |*mbc| mbc.load(save_data),
        }
    }
    pub fn deinit(self: *Cartridge) void {
        switch (self.mbc) {
            inline else => |*mbc| mbc.deinit(),
        }
    }
};

fn getRamSize(byte: u8) usize {
    return switch (byte) {
        0x00 => 0, // No RAM
        0x02 => 8 * 1024, // 8KiB - 1 bank
        0x03 => 32 * 1024, // 32KiB - 4 8KiB banks
        0x04 => 128 * 1024, // 128KiB - 16 8KiB banks
        0x05 => 64 * 1024, // 64KiB - 8 8KiB banks
        else => 0,
    };
}
