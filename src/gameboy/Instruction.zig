// This is not used, just testing something out...
const Console = @import("console.zig").Console;
const Register = @import("register.zig").Register;
const Cpu = @import("cpu.zig").Cpu;
const Bus = @import("bus.zig").Bus;
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

fn ADC_A_HL(cpu: *Cpu) u8 {
    x.execAdd8(cpu, &cpu.AF, Register.setHi, cpu.AF.getHi(), cpu.mem.read8(cpu.HL.getHiLo()), true);
    return 2;
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

fn ADC_A_r8(cpu: *Cpu, opcode: u8) u8 {
    execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(@truncate(opcode)), true);
    return 1;
}

pub fn execAdd8(
    cpu: *Cpu,
    dest_idx: u3,
    set: *const fn (*Cpu, u3, u8) void,
    op1: u8,
    op2: u8,
    useCarry: bool,
) void {
    const carry = if (useCarry) cpu.get_c() else 0;
    const r1 = @addWithOverflow(op1, op2);
    const r2 = @addWithOverflow(r1[0], carry);

    set(cpu, dest_idx, r2[0]);

    cpu.set_z(r2[0] == 0);
    cpu.set_n(false);
    cpu.set_h(halfCarryAdd(@truncate(op1), @truncate(op2), carry));
    cpu.set_c(r1[1] == 1 or r2[1] == 1);
}
