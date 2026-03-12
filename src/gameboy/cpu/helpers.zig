const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const Register = @import("register.zig").Register;

// Performs a check on whether a 4 bit addition with carry overflowed, used
//   for H flag
pub fn halfCarryAdd(a: u4, b: u4, c: u1) bool {
    const hc1 = @addWithOverflow(a, b);
    const hc2 = @addWithOverflow(hc1[0], c);
    return hc1[1] == 1 or hc2[1] == 1;
}

// Performs a check on whether a 4 bit subtraction with carry overflowed, used
//   for H flag
pub fn halfCarrySub(a: u4, b: u4, c: u1) bool {
    const hc1 = @subWithOverflow(a, b);
    const hc2 = @subWithOverflow(hc1[0], c);
    return hc1[1] == 1 or hc2[1] == 1;
}

// Checks flags depending on cond bits set
pub fn check_condition(cpu: *Cpu, cond: u2) bool {
    switch (cond) {
        0x0 => return cpu.get_z() == 0,
        0x1 => return cpu.get_z() == 1,
        0x2 => return cpu.get_c() == 0,
        0x3 => return cpu.get_c() == 1,
    }
}
