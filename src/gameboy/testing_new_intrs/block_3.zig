const R8 = @import("decode.zig").R8;
const R16 = @import("decode.zig").R16;
const R16stk = @import("decode.zig").R16stk;
const R16mem = @import("decode.zig").R16mem;
const Cpu = @import("new_cpu.zig").Cpu;
const x = @import("new_functions.zig");
const check_cond = @import("../helpers.zig").check_condition;

pub const Block3 = packed struct(u8) {
    z: u3,
    y: u3,

    _prefix: u2 = 0,

    pub fn execute(self: *Block3, cpu: *Cpu) void {
        switch (self.z) {
            0x4 => if (self.y < 4 and check_cond(cpu, @truncate(self.y)))
                x.execCall(cpu, cpu.pc_pop_16()),
            0x5 => if (self.y & 1 == 0) {
                const reg: R16stk = @bitCast(self.y >> 1);
                cpu.setR16stk(reg, cpu.sp_pop_16());
            } else if (self.y == 1) x.execCall(cpu, cpu.pc_pop_16()),
            0x6 => @as(AluImmOp, @bitCast(self)).execute(cpu),
            0x7 => x.execCall(cpu, self.y << 3), // tgt * 8
        }
    }
};

pub const AluImmOp = packed struct(u8) {
    _unused: u3,
    op: enum(u3) { ADD = 0, ADC = 1, SUB = 2, SBC = 3, AND = 4, XOR = 5, OR = 6, CP = 7 },
    _prefix: u2 = 2,

    pub fn execute(self: *AluImmOp, cpu: *Cpu) void {
        switch (self.op) {
            .ADD => x.execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8(), false),
            .ADC => x.execAdd8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8(), true),
            .SUB => x.execSub8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8(), false),
            .SBC => x.execSub8(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8(), true),
            .AND => x.execAnd(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8()),
            .XOR => x.execXor(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8()),
            .OR => x.execOr(cpu, 7, Cpu.set8, cpu.AF.getHi(), cpu.pc_pop_8()),
            .CP => x.execCp(cpu, cpu.AF.getHi(), cpu.pc_pop_8()),
        }
    }
};
