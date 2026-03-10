// This is not used, just testing something out...
const Console = @import("../console.zig").Console;
const Register = @import("../register.zig").Register;
const Cpu = @import("new_cpu.zig").Cpu;
const Bus = @import("../bus.zig").Bus;
const x = @import("new_functions.zig");
const std = @import("std");
const AluOp = @import("block_2.zig").AluOp;
const LdR8R8 = @import("block_1.zig").LdR8R8;
const Block0 = @import("block_0.zig").Block0;

const Instruction = union {
    alu_op: AluOp,
    ld_r8_r8: LdR8R8,
};

const Generic = packed struct(u8) {
    z: u3,
    y: u3,
    x: u2,
};

pub const R8 = enum(u3) { b = 0, c = 1, d = 2, e = 3, h = 4, l = 5, hl = 6, a = 7 };
pub const R16 = enum(u2) { bc = 0, de = 1, hl = 2, sp = 3 };
pub const R16stk = enum(u2) { bc = 0, de = 1, hl = 2, af = 3 };
pub const R16mem = enum(u2) { bc = 0, de = 1, hli = 2, hld = 3 };

pub fn execute(raw_instruction: u8, cpu: *Cpu) Instruction {
    const generic_instruction: Generic = raw_instruction;
    switch (generic_instruction.x) {
        0b00 => {
            var instr: Block0 = @bitCast(raw_instruction);
            instr.execute(cpu);
        },
        0b01 => {
            var instr: LdR8R8 = @bitCast(raw_instruction);
            instr.execute(cpu);
        },
        0b10 => {
            var instr: AluOp = @bitCast(raw_instruction);
            instr.execute(cpu);
        },
    }
}
