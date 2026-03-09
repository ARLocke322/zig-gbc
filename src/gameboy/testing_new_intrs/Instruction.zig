// This is not used, just testing something out...
const Console = @import("../console.zig").Console;
const Register = @import("../register.zig").Register;
const Cpu = @import("../cpu.zig").Cpu;
const Bus = @import("../bus.zig").Bus;
const x = @import("new_functions.zig");
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

pub fn get8(self: *Cpu, register_idx: u3) u8 {
    // if normal register => return register value
    // if HL => return value read from memory
    return switch (register_idx) {
        0 => self.BC.getHi(),
        1 => self.BC.getLo(),
        2 => self.DE.getHi(),
        3 => self.DE.getLo(),
        4 => self.HL.getHi(),
        5 => self.HL.getLo(),
        6 => self.mem.read8(self.HL.getHiLo()),
        7 => self.AF.getHi(),
    };
}

pub fn set8(self: *Cpu, register_idx: u3, value: u8) void {
    // if normal register => return register value
    // if HL => return value read from memory
    switch (register_idx) {
        0 => self.BC.setHi(value),
        1 => self.BC.setLo(value),
        2 => self.DE.setHi(value),
        3 => self.DE.setLo(value),
        4 => self.HL.setHi(value),
        5 => self.HL.setLo(value),
        6 => self.mem.write8(self.HL.getHiLo(), value),
        7 => self.AF.setHi(value),
    }
}

pub const five_three = packed struct(u8) {
    operand: u3,
    op: u3,
    prefix: u2,

    pub fn execute(self: *five_three, cpu: *Cpu) void {
        switch (self.opcode) {
            0x10 => x.execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), false),
            0x11 => x.execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), true),
            0x12 => x.execSub8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), false),
            0x13 => x.execSub8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), true),
            0x14 => x.execAnd(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand)),
            0x15 => x.execXor(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand)),
            0x16 => x.execOr(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand)),
            0x17 => x.execCp(cpu, cpu.AF.getHi(), cpu.get8(self.operand)),
            else => unreachable,
        }
    }
};
