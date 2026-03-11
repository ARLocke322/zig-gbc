const R8 = @import("decode.zig").R8;
const R16 = @import("decode.zig").R16;
const R16stk = @import("decode.zig").R16stk;
const R16mem = @import("decode.zig").R16mem;
const Cpu = @import("cpu.zig").Cpu;
const x = @import("functions.zig");
const check_cond = @import("../helpers.zig").check_condition;

pub const Block0 = packed struct(u8) {
    z: u3,
    y: u3,

    _prefix: u2 = 0,

    // I hate this but am stuck with it
    pub fn execute(self: Block0, cpu: *Cpu) void {
        switch (self.z) {
            0x0 => switch (self.y) {
                0x0 => return, // NOP
                0x1 => cpu.write16(cpu.pc_pop_16(), cpu.SP.getHiLo()),
                0x2 => return, // STOP
                0x3 => x.execJumpRelative(cpu, @bitCast(cpu.pc_pop_8())),
                0x4...0x7 => if (check_cond(cpu, @truncate(self.y)))
                    x.execJumpRelative(cpu, @bitCast(cpu.pc_pop_8())),
            },
            0x1 => {
                const reg: R16 = @bitCast(self.y >> 1);
                if (self.y & 1 == 0) {
                    x.execLoad16(cpu, reg, Cpu.setR16, cpu.pc_pop_16());
                } else x.execAdd16(cpu, .hl, Cpu.setR16, cpu.getR16(reg));
            },
            0x2 => {
                const reg: R16mem = @bitCast(self.y >> 1);
                if (self.y & 1 == 0) {
                    x.execLoad16mem(cpu, reg, Cpu.setR16mem, cpu.AF.getHi());
                } else x.execLoad8(cpu, .a, Cpu.setR8, cpu.getR16mem(reg));
            },
            0x3 => {
                const reg: R16 = @bitCast(self.y >> 1);
                if (self.y & 1 == 0) {
                    x.execInc16(cpu, reg, Cpu.setR16, cpu.getR16(reg));
                } else x.execDec16(cpu, reg, Cpu.setR16, cpu.getR16(reg));
            },
            0x4 => {
                const reg: R8 = @bitCast(self.y);
                x.execInc8(cpu, @bitCast(reg), Cpu.setR8, cpu.getR8(reg));
            },
            0x5 => {
                const reg: R8 = @bitCast(self.y);
                x.execDec8(cpu, @bitCast(reg), Cpu.setR8, cpu.getR8(reg));
            },
            0x6 => x.execLoad8(cpu, @bitCast(self.y), Cpu.setR8, cpu.pc_pop_8()),

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
