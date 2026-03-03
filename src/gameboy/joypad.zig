const assert = @import("std").debug.assert;

pub const Joypad = @This();

p1: u8,
dpad: u8,
buttons: u8,

pub fn init() Joypad {
    return Joypad{
        .p1 = 0x30,
        .dpad = 0x0F,
        .buttons = 0x0F,
    };
}

// Reads the joypad register at address 0xFF00, returns the current button
//  being pressed
pub fn read(self: *Joypad, addr: u16) u8 {
    assert(addr == 0xFF00);

    var low: u8 = 0x0F;

    const select_dpad: bool = (self.p1 & 0x10) == 0;
    const select_buttons: bool = (self.p1 & 0x20) == 0;

    if (select_dpad) {
        low &= self.dpad;
    }

    if (select_buttons) {
        low &= self.buttons;
    }

    return 0xC0 | self.p1 | low;
}

// Writes to the joypad register at address 0xFF00, only writes bits 4 & 5
pub fn write(self: *Joypad, addr: u16, val: u8) void {
    assert(addr == 0xFF00);
    self.p1 = val & 0x30;
}
