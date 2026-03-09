// This is not used, just testing something out...
const Console = @import("../console.zig").Console;
const Register = @import("../register.zig").Register;
const Cpu = @import("../cpu.zig").Cpu;
const Bus = @import("../bus.zig").Bus;
const x = @import("new_functions.zig");
const std = @import("std");
const check_cond = @import("../helpers.zig").check_condition;

pub fn execute(raw_instruction: u8, cpu: *Cpu) Instruction {
    const generic_instruction: Generic = raw_instruction;
    switch (generic_instruction.x) {
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

const Instruction = union {
    alu_op: AluOp,
};

const Generic = packed struct(u8) {
    z: u3,
    y: u3,
    x: u2,
};

const LdR8R8 = packed struct(u8) {
    src: u3,
    dst: u3,
    _prefix: u2 = 1,

    pub fn execute(self: *LdR8R8, cpu: *Cpu) void {
        if (self.src == 6 and self.dst == 6) { // LD HL HL = HALT
            cpu.halted = true;
        } else x.execLoad8(cpu, self.dst, Cpu.set8, cpu.get8(self.src));
    }
};

const AluOp = packed struct(u8) {
    operand: u3,
    op: enum(u3) { ADD = 0, ADC = 1, SUB = 2, SBC = 3, AND = 4, XOR = 5, OR = 6, CP = 7 },
    _prefix: u2 = 2,

    pub fn execute(self: *AluOp, cpu: *Cpu) void {
        switch (self.op) {
            .ADD => x.execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), false),
            .ADC => x.execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), true),
            .SUB => x.execSub8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), false),
            .SBC => x.execSub8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand), true),
            .AND => x.execAnd(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand)),
            .XOR => x.execXor(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand)),
            .OR => x.execOr(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.get8(self.operand)),
            .CP => x.execCp(cpu, cpu.AF.getHi(), cpu.get8(self.operand)),
            else => unreachable,
        }
    }
};

const Block0 = packed struct(u8) {
    z: u3,
    y: u3,

    _prefix: u1 = 0,

    // I hate this but am stuck with it
    pub fn execute(self: *Block0, cpu: *Cpu) void {
        switch (self.z) {
            0x0 => switch (self.y) {
                0x0 => return, // NOP
                0x2 => return, // STOP
                0x3 => x.execJumpRelative(cpu, @bitCast(cpu.pc_pop_8())),
                0x4...0x8 => if (check_cond(cpu, @truncate(self.y)))
                    x.execJumpRelative(cpu, @bitCast(cpu.pc_pop_8())),
            },
            0x7 => switch (self.y) {
                0x0 => x.execRotateLeft(cpu, 7, Cpu.set8, cpu.AF.getHi(), false),
                0x1 => x.execRotateRight(cpu, 7, Cpu.set8, cpu.AF.getHi(), false),
                0x2 => x.execRotateLeft(cpu, 7, Cpu.set8, cpu.AF.getHi(), true),
                0x3 => x.execRotateRight(cpu, 7, Cpu.set8, cpu.AF.getHi(), true),
                0x4 => x.execDAA(cpu),
                0x5 => x.execCPL(cpu),
                0x6 => x.execSCF(cpu),
                0x7 => x.execCCF(cpu),
            },
        }
    }
};
