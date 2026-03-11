const R8 = @import("decode.zig").R8;
const Cpu = @import("cpu.zig").Cpu;
const x = @import("functions.zig");

pub const AluOp = packed struct(u8) {
    operand: R8,
    op: enum(u3) { ADD = 0, ADC = 1, SUB = 2, SBC = 3, AND = 4, XOR = 5, OR = 6, CP = 7 },
    _prefix: u2 = 2,

    pub fn execute(self: AluOp, cpu: *Cpu) void {
        switch (self.op) {
            .ADD => x.execAdd8(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand), false),
            .ADC => x.execAdd8(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand), true),
            .SUB => x.execSub8(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand), false),
            .SBC => x.execSub8(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand), true),
            .AND => x.execAnd(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand)),
            .XOR => x.execXor(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand)),
            .OR => x.execOr(cpu, .a, Cpu.setR8, cpu.AF.getHi(), cpu.getR8(self.operand)),
            .CP => x.execCp(cpu, cpu.AF.getHi(), cpu.getR8(self.operand)),
        }
    }
};
