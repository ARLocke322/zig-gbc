const Console = @import("console.zig").Console;
const Register = @import("register.zig").Register;
const Cpu = @import("cpu.zig").Cpu;
const x = @import("functions.zig");
const std = @import("std");

const Instruction = @This();

gb: *Console,
opcode: u8,

pub fn init(gb: *Console, opcode: u8) Instruction {
    return .{
        .gb = gb,
        .opcode = opcode,
    };
}

pub fn execute(self: *Instruction) void {
    const r = self.get_r8(self.gb.cpu, @truncate(self.opcode));
    x.execAdd8(self.cpu, &self.cpu.AF, Register.setHi, self.cpu.AF.getHi(), r.get(r.reg), false);
    self.gb.stepOne();
}

pub fn get_r8(cpu: *Cpu, index: u3) struct {
    reg: *Register,
    get: *const fn (*Register) u8,
    set: *const fn (*Register, u8) void,
} {
    std.debug.assert(index != 6);
    return switch (index) {
        0 => .{ .reg = &cpu.BC, .get = Register.getHi, .set = Register.setHi },
        1 => .{ .reg = &cpu.BC, .get = Register.getLo, .set = Register.setLo },
        2 => .{ .reg = &cpu.DE, .get = Register.getHi, .set = Register.setHi },
        3 => .{ .reg = &cpu.DE, .get = Register.getLo, .set = Register.setLo },
        4 => .{ .reg = &cpu.HL, .get = Register.getHi, .set = Register.setHi },
        5 => .{ .reg = &cpu.HL, .get = Register.getLo, .set = Register.setLo },
        6 => unreachable,
        7 => .{ .reg = &cpu.AF, .get = Register.getHi, .set = Register.setHi },
    };
}

fn get_hl() void {}
