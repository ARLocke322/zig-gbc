const Bus = @import("bus.zig").Bus;
const assert = @import("std").debug.assert;

pub const Apu = @This();

bus: *Bus,

rAUD1SWEEP: u8,
rAUD1LEN: u8,
rAUD1ENV: u8,
rAUD1LOW: u8,
rAUD1HIGH: u8,
rAUD2LEN: u8,
rAUD2ENV: u8,
rAUD2LOW: u8,
rAUD2HIGH: u8,
rAUD3ENA: u8,
rAUD3LEN: u8,
rAUD3LEVEL: u8,
rAUD3LOW: u8,
rAUD3HIGH: u8,
rAUD4LEN: u8,
rAUD4ENV: u8,
rAUD4POLY: u8,
rAUD4GO: u8,

// Master volume & VIN panning - FF24
// |   7   |  6 5 4   |   3   |  2 1 0   |
// | VIN L | L Volume | VIN R | R Volume |
rAUDVOL: u8,

// Sound Panning - FF25
// |   7   |   6   |   5   |   4   |   3   |   2   |   1   |   0   |
// | CH4 L | CH3 L | CH2 L | CH1 L | CH4 R | CH3 R | CH2 R | CH1 R |
rAUDTERM: u8,

// Audio Master Control - FF26
// |      7       | 6 5 4 |    3    |    2    |    1    |    0    |
// | Audio on/off | Blank | CH4 on? | CH3 on? | CH2 on? | CH1 on? |
rAUDENA: u8,

pub fn init(bus: *Bus) Apu {
    return Apu{ .bus = bus };
}

pub fn read(self: *Apu, addr: u16) u8 {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF4F));
    return switch (addr) {
        0xFF10 => self.rAUD1SWEEP,
        0xFF11 => self.rAUD1LEN,
        0xFF12 => self.rAUD1ENV,
        0xFF13 => self.rAUD1LOW,
        0xFF14 => self.rAUD1HIGH,
        0xFF16 => self.rAUD2LEN,
        0xFF17 => self.rAUD2ENV,
        0xFF18 => self.rAUD2LOW,
        0xFF19 => self.rAUD2HIGH,
        0xFF1A => self.rAUD3ENA,
        0xFF1B => self.rAUD3LEN,
        0xFF1C => self.rAUD3LEVEL,
        0xFF1D => self.rAUD3LOW,
        0xFF1E => self.rAUD3HIGH,
        0xFF20 => self.rAUD4LEN,
        0xFF21 => self.rAUD4ENV,
        0xFF22 => self.rAUD4POLY,
        0xFF23 => self.rAUD4GO,
        0xFF24 => self.rAUDVOL,
        0xFF25 => self.rAUDTERM,
        0xFF26 => self.rAUDENA,
        else => unreachable,
    };
}

pub fn write(self: *Apu, addr: u16, val: u8) void {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF4F));
    switch (addr) {
        0xFF24 => self.rAUDVOL = val,
        0xFF25 => self.rAUDTERM = val,
        0xFF26 => self.rAUDENA = (self.rAUDENA & 0x7F) | (val & 0x80),
        else => unreachable,
    }
}
