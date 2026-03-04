const assert = @import("std").debug.assert;

// Component to track interrupt status'
pub const InterruptController = @This();

// Interrupt Enable register, controls whether a handler may be called
//   | 7 6 5 |   4    |   3    |   2   |  1  |   0    |
//   | Blank | Joypad | Serial | Timer | LCD | VBLANK |
IE: u8,

// Interrupt Flag Register, controls whether a handler is being requested
//   | 7 6 5 |   4    |   3    |   2   |  1  |   0    |
//   | Blank | Joypad | Serial | Timer | LCD | VBLANK |
IF: u8,

// Enables cleaner req/ack syntax: request(InterruptController.VBLANK)
pub const VBLANK = 0;
pub const LCD_STAT = 1;
pub const TIMER = 2;
pub const SERIAL = 3;
pub const JOYPAD = 4;

// Zero-initialises IE + IF
pub fn init() InterruptController {
    return InterruptController{
        .IE = 0,
        .IF = 0,
    };
}

// Reads the IE or IF registers
pub fn read8(self: *InterruptController, addr: u16) u8 {
    assert(addr == 0xFFFF or addr == 0xFF0F);
    return switch (addr) {
        0xFFFF => self.IE,
        0xFF0F => self.IF,
        else => unreachable,
    };
}

// Writes to the IE or IF registers
pub fn write8(self: *InterruptController, addr: u16, val: u8) void {
    assert(addr == 0xFFFF or addr == 0xFF0F);
    switch (addr) {
        0xFFFF => self.IE = val,
        0xFF0F => self.IF = val,
        else => unreachable,
    }
}

// Requests an interrupt, sets the corresponding bit in the IF register
pub fn request(self: *InterruptController, interrupt_bit: u3) void {
    self.IF |= (@as(u8, 1) << interrupt_bit);
}

// Acknowledges an interrupt, clears the corresponding bit in the IF register
pub fn acknowledge(self: *InterruptController, interrupt_bit: u3) void {
    self.IF &= ~(@as(u8, 1) << interrupt_bit);
}

// Gets interrupts that are requested and have yet to be acknowledged
pub fn get_pending(self: *InterruptController) u8 {
    return self.IF & self.IE;
}
