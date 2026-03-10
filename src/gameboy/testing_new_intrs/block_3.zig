const R8 = @import("decode.zig").R8;
const R16 = @import("decode.zig").R16;
const R16stk = @import("decode.zig").R16stk;
const R16mem = @import("decode.zig").R16mem;
const Cpu = @import("new_cpu.zig").Cpu;
const Cb = @import("cb.zig").Cb;
const x = @import("new_functions.zig");
const check_cond = @import("../helpers.zig").check_condition;

pub const Block3 = packed struct(u8) {
    z: u3,
    y: u3,

    _prefix: u2 = 0,

    pub fn execute(self: *Block3, cpu: *Cpu) void {
        switch (self.z) {
            0x0 => switch (self.y) {
                0x0...0x3 => if (check_cond(cpu, @truncate(self.y))) x.execRet(cpu),
                0x4 => cpu.mem.write8(0xFF00 || (@as(u16, cpu.pc_pop_8())), cpu.AF.getHi()),
                0x5 => x.execAdd16Signed(cpu, .sp, Cpu.setR16, cpu.SP.getHiLo(), cpu.pc_pop_8()),
                0x6 => cpu.AF.setHi(cpu.mem.read8(0xFF00 || (@as(u16, cpu.pc_pop_8())))),
                0x7 => x.execAdd16Signed(cpu, .hl, Cpu.set, cpu.SP.getHiLo(), cpu.pc_pop_8()),
            },
            0x1 => switch (self.y) {
                0x1 => x.execRet(cpu),
                0x2, 0x4, 0x6 => {
                    const reg: R16stk = @bitCast(self.y >> 1);
                    cpu.setR16stk(reg, cpu.sp_pop_16());
                },
                0x3 => {
                    x.execRet(cpu);
                    cpu.IME = true;
                },
                0x5 => x.execJump(cpu, cpu.HL.getHiLo()),
                0x7 => cpu.SP.set(cpu.HL.getHiLo()),
            },
            0x2 => switch (self.y) {
                0x0...0x3 => if (check_cond(cpu, @truncate(self.y)))
                    x.execJump(cpu, cpu.pc_pop_16()),
                0x4 => cpu.mem.write8((0xFF00 | @as(u16, cpu.BC.getLo())), cpu.AF.getHi()),
                0x5 => cpu.mem.write8(cpu.pc_pop_16(), cpu.AF.getHi()),
                0x6 => cpu.AF.setHi(cpu.mem.read8((0xFF00) | @as(u16, cpu.BC.getLo()))),
                0x7 => cpu.AF.setHi(cpu.mem.read8(cpu.pc_pop_16())),
            },
            0x3 => switch (self.y) {
                0x0 => x.execJump(cpu, cpu.pc_pop_16()),
                0x1 => @as(Cb, @bitCast(cpu.pc_pop_8())).execute(cpu),
                0x6 => cpu.IME = false, // DI
                0x7 => cpu.IME_scheduled = false, // DI
                else => {},
            },
            0x4 => if (self.y < 4 and check_cond(cpu, @truncate(self.y)))
                x.execCall(cpu, cpu.pc_pop_16()),
            0x5 => if (self.y & 1 == 0) {
                const reg: R16stk = @bitCast(self.y >> 1);
                cpu.sp_push_16(cpu.getR16stk(reg));
            } else if (self.y == 1) x.execCall(cpu, cpu.pc_pop_16()),
            0x6 => @as(AluImmOp, @bitCast(self)).execute(cpu),
            0x7 => x.execCall(cpu, self.y << 3), // tgt * 8
        }
    }
};

pub const JumpLoadOp = packed struct(u8) {
    _unused: u3,
    opcode: enum(u2) { LDH_C_A = 0, LD_n16_A = 1, LDH_A_C = 2, LD_A_n16 = 3 },
    is_ld: bool,
    _prefix: u2,

    fn execute(self: JumpLoadOp, cpu: *Cpu) void {
        if (self.is_ld) {
            switch (self.opcode) {
                .LDH_C_A => {},
                .LD_n16_A => {},
                .LDH_A_C => {},
                .LD_A_n16 => {},
            }
        } else {
            const cond: u2 = @bitCast(self.opcode);
            const addr = cpu.pc_pop_16();
            if (check_cond(cpu, cond)) x.execJump(cpu, addr);
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
