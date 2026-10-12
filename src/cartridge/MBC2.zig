const std = @import("std");
const assert = std.debug.assert;

pub const MBC2 = struct {
    allocator: std.mem.Allocator,

    rom: []u8,
    ram: []u8,

    rom_bank: u4,

    ram_enabled: bool,

    pub fn init(allocator: std.mem.Allocator, data: []const u8, ram_size: usize) !MBC2 {
        assert(data.len <= (256 * 1024)); // Up to 256 KiB
        assert(ram_size <= (512)); // Up to 512 * 4 bits
        // assert(data.len / 0x4000 > 0 and std.math.isPowerOfTwo(data.len / 0x4000));

        const rom = try allocator.alloc(u8, data.len);
        @memcpy(rom, data);

        const ram = try allocator.alloc(u8, ram_size);
        @memset(ram, 0);

        return MBC2{
            .allocator = allocator,
            .rom = rom,
            .rom_bank = 0x1,
            .ram = ram,
            .ram_enabled = false,
        };
    }

    pub fn read(self: *MBC2, addr: u16) u8 {
        assert((addr >= 0x0000 and addr <= 0x7FFF) or
            addr >= 0xA000 and addr <= 0xBFFF);
        return switch (addr) {
            0x0000...0x3FFF => self.rom[addr],
            0x4000...0x7FFF => {
                const ix = addr + ((@as(u32, self.rom_bank) - 1) * 0x4000);
                assert(ix < self.rom.len);
                return self.rom[ix];
            },
            0xA000...0xA1FF => if (self.ram_enabled)
                @as(u8, self.ram[addr - 0xA000])
            else
                0xFF,
            0xA200...0xBFFF => if (self.ram_enabled)
                @as(u8, self.ram[(addr - 0xA200) & 0x01FF]) // only bottom 9
            else
                0xFF,
            else => unreachable,
        } & 0xF;
    }

    pub fn write(self: *MBC2, addr: u16, val: u8) void {
        assert((addr >= 0x000 and addr <= 0x3FFF) or
            (addr >= 0xA000 and addr <= 0xBFFF));
        switch (addr) {
            0x0000...0x3FFF => {
                if ((addr & 0x0100) == 0x0) { // enable/disable ram
                    self.ram_enabled = if ((val & 0xF) == 0xA) true else false;
                } else { // change rom bank
                    self.rom_bank = @truncate(val);
                    self.update_invalid_rom_bank();
                }
            },
            0xA000...0xA1FF => {
                if (self.ram_enabled) self.ram[addr - 0xA000] = @truncate(val);
            },
            0xA200...0xBFFF => {
                if (self.ram_enabled) self.ram[(addr - 0xA200) & 0x01FF] = @truncate(val);
            },

            else => unreachable,
        }
    }

    pub fn save(self: *MBC2) []u8 {
        return self.ram;
    }

    pub fn load(self: *MBC2, data: []u8) void {
        assert(data.len == self.ram.len);
        @memcpy(self.ram, data);
    }

    fn update_invalid_rom_bank(self: *MBC2) void {
        if (self.rom_bank == 0x0) {
            self.rom_bank += 1;
        }
    }

    pub fn deinit(self: *MBC2) void {
        self.allocator.free(self.rom);
        self.allocator.free(self.ram);
    }
};

// TESTS

test "should init with valid ram/rom sizes" {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    try std.testing.expect(cart.rom[0] == 0x00);
    try std.testing.expect(cart.rom[0xEFFF] == 0x00);
    try std.testing.expect(cart.rom.len == 0xF000);
    try std.testing.expect(cart.ram.len == 32);
    try std.testing.expect(cart.rom_bank == 1);
    try std.testing.expect(cart.ram_enabled == false);
}

test "should read from rom bank 0 correctly " {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xC000], 32);
    defer cart.deinit();

    cart.rom[0x0100] = 0x01;
    try std.testing.expect(cart.read(0x0100) == 0x01);
}

test "should read from rom bank 1 correctly " {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    cart.rom[0x5000] = 0x01;
    try std.testing.expect(cart.read(0x5000) == 0x01);
}

test "should read from rom bank N correctly " {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    cart.rom[0x9000] = 0x01;
    cart.rom_bank = 2;
    try std.testing.expect(cart.read(0x5000) == 0x01);
}

test "should read from ram correctly" {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    cart.ram_enabled = true;
    cart.ram[0x0001] = 0x01;
    try std.testing.expect(cart.read(0xA001) == 0x01);
    try std.testing.expect(cart.read(0xB001) == 0x01);

    cart.write(0x0000, 0xA);
    try std.testing.expect(cart.read(0xA001) == 0x01);
    try std.testing.expect(cart.read(0xB001) == 0x01);
}

test "should change rom banks correctly " {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    cart.write(0x0100, 0x2);

    try std.testing.expect(cart.rom_bank == 0x02);
}

test "should enable ram correctly" {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    cart.write(0x0000, 0x1);
    try std.testing.expect(cart.ram_enabled == false);

    cart.write(0x0000, 0xA);
    try std.testing.expect(cart.ram_enabled == true);
}

test "should read correctly after changing rom banks" {
    const data: [0xF000]u8 = @splat(0x00);
    var cart = try MBC2.init(std.testing.allocator, data[0..0xF000], 32);
    defer cart.deinit();

    cart.rom[0x9000] = 0x1;
    cart.write(0x0100, 0x2);

    try std.testing.expect(cart.read(0x5000) == 0x01);
}
