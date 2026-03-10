const R8 = @import("decode.zig").R8;
const Cpu = @import("new_cpu.zig").Cpu;
const x = @import("new_functions.zig");

pub const AluOp = packed struct(u8) {
    operand: R8,
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
        }
    }
};
