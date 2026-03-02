const std = @import("std");
const assert = std.debug.assert;

pub const MBC5 = struct {
    allocator: std.mem.Allocator,

    rom: []u8,
    ram: []u8,

    rom_bank: u9,
    ram_bank: u4,

    ram_enabled: bool,

    pub fn init(allocator: std.mem.Allocator, data: []const u8, ram_size: usize) !MBC5 {
        assert(data.len <= (8 * 1024 * 1024)); // Up to 8 MiB
        assert(ram_size == (8 * 1024) or
            ram_size == (32 * 1024) or
            ram_size == 128 * 1024); // Up to 512 * 4 bits

        const rom = try allocator.alloc(u8, data.len);
        @memcpy(rom, data);

        const ram = try allocator.alloc(u8, ram_size);
        @memset(ram, 0);

        return MBC5{
            .allocator = allocator,
            .rom = rom,
            .rom_bank = 0x0,
            .ram_bank = 0x0,
            .ram = ram,
            .ram_enabled = false,
        };
    }

    pub fn read(self: *MBC5, addr: u16) u8 {
        assert((addr >= 0x0000 and addr <= 0x7FFF) or
            addr >= 0xA000 and addr <= 0xBFFF);
        return switch (addr) {
            0x0000...0x3FFF => self.rom[addr],
            0x4000...0x7FFF => {
                const ix = (addr - 0x4000) + (@as(u32, self.rom_bank) * 0x4000);
                assert(ix < self.rom.len);
                return self.rom[ix];
            },
            0xA000...0xBFFF => if (self.ram_enabled) {
                const ix = (addr - 0xA000) + (@as(u32, self.ram_bank) * 0x2000);
                assert(ix < self.ram.len);
                return self.ram[ix];
            } else 0xFF,
            else => unreachable,
        };
    }

    pub fn write(self: *MBC5, addr: u16, val: u8) void {
        assert((addr >= 0x000 and addr <= 0x5FFF) or
            (addr >= 0xA000 and addr <= 0xBFFF));
        switch (addr) {
            0x0000...0x1FFF => {
                if (val == 0xA) {
                    self.ram_enabled = true;
                } else if (val == 0x00) {
                    self.ram_enabled = false;
                }
            },
            0x2000...0x2FFF => self.rom_bank =
                (self.rom_bank & 0x100) | val,
            0x3000...0x3FFF => self.rom_bank =
                (self.rom_bank & 0x0FF) | (@as(u9, (val & 0x1)) << 0x08),
            0x4000...0x5FFF => {
                if (self.ram_enabled) self.ram_bank = @truncate(val & 0xF);
            },
            0xA000...0xA1FF => if (self.ram_enabled) {
                self.ram[addr - 0xA000] = @truncate(val);
            },
            0xA200...0xBFFF => if (self.ram_enabled) {
                const ix = (addr - 0xA000) + (@as(u32, self.ram_bank) * 0x2000);
                assert(ix < self.ram.len);
                self.ram[ix] = val;
            },

            else => unreachable,
        }
    }

    pub fn save(self: *MBC5) []u8 {
        return self.ram;
    }

    pub fn load(self: *MBC5, data: []u8) void {
        assert(data.len == self.ram.len);
        @memcpy(self.ram, data);
    }

    fn update_invalid_rom_bank(self: *MBC5) void {
        if (self.rom_bank == 0x0) {
            self.rom_bank += 1;
        }
    }

    pub fn deinit(self: *MBC5) void {
        self.allocator.free(self.rom);
        self.allocator.free(self.ram);
    }
};
