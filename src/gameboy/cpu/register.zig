// Represents a single CPU register
pub const Register = @This();

value: u16,

// Initializes a register with a value
pub fn init(val: u16) Register {
    return Register{ .value = val };
}

// Gets upper byte of the register
pub fn getHi(self: *Register) u8 {
    return @truncate(self.value >> 8);
}

// Gets lower byte of the register
pub fn getLo(self: *Register) u8 {
    return @truncate(self.value);
}

// Gets full 16 bit register
pub fn getHiLo(self: *Register) u16 {
    return self.value;
}

// Sets the upper byte of the register
pub fn setHi(self: *Register, val: u8) void {
    self.value = @as(u16, val) << 8 | (self.value & 0xFF);
}

// Sets the lower byte of the register
pub fn setLo(self: *Register, val: u8) void {
    self.value = (self.value & 0xFF00) | val;
}

// Sets the full 16 bit register
pub fn set(self: *Register, val: u16) void {
    self.value = val;
}

// Increments the register (wraps)
pub fn inc(self: *Register) void {
    self.value +%= 1;
}

// Decrements the register (wraps)
pub fn dec(self: *Register) void {
    self.value -%= 1;
}

pub const R8 = enum(u3) {
    b = 0,
    c = 1,
    d = 2,
    e = 3,
    h = 4,
    l = 5,
    hl = 6,
    a = 7,
};

pub const R16 = enum(u2) {
    bc = 0,
    de = 1,
    hl = 2,
    sp = 3,
};

pub const R16stk = enum(u2) {
    bc = 0,
    de = 1,
    hl = 2,
    af = 3,
};

pub const R16mem = enum(u2) {
    bc = 0,
    de = 1,
    hli = 2,
    hld = 3,
};
