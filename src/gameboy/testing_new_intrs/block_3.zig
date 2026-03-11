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
            0x1 => @as(StackRetOp, @bitCast(self)).execute(),
            0x2 => @as(JumpLoadOp, @bitCast(self)).execute(cpu),
            0x3 => switch (self.y) {
                0x0 => x.execJump(cpu, cpu.pc_pop_16()),
                0x1 => @as(Cb, @bitCast(cpu.pc_pop_8())).execute(cpu),
                0x6 => cpu.IME = false, // DI
                0x7 => cpu.IME_scheduled = false, // DI
                else => {},
            },
            0x4 => if (self.y < 4) {
                const addr = cpu.pc_pop_16();
                if (check_cond(cpu, @truncate(self.y))) x.execCall(cpu, addr);
            },
            0x5 => if (self.y & 1 == 0) {
                const reg: R16stk = @bitCast(self.y >> 1);
                cpu.sp_push_16(cpu.getR16stk(reg));
            } else if (self.y == 1) x.execCall(cpu, cpu.pc_pop_16()),
            0x6 => @as(AluImmOp, @bitCast(self)).execute(cpu),
            0x7 => x.execCall(cpu, self.y << 3), // tgt * 8
        }
    }
};

const Block3Z0 = packed struct(u8) {
    _unused: u3 = 0,
    opcode: enum(u2) { LDH_n8_A = 0, ADD_SP_n8 = 1, LDH_A_n8 = 2, LD_HL_SP_plus_n8 = 3 },
    is_not_RET: bool,
    _prefix: u2,

    fn execute(self: Block3Z0, cpu: *Cpu) void {
        if (self.is_not_RET) {
            switch (self.opcode) {
                .LDH_n8_A => {
                    const addr: u16 = 0xFF00 | @as(u16, cpu.pc_pop_8());
                    cpu.mem.write8(addr, cpu.AF.getHi());
                },
                .ADD_SP_n8 => {
                    const offset: i8 = @bitCast(cpu.pc_pop_8());
                    x.execAdd16Signed(cpu, &cpu.SP, Register.set, cpu.SP.getHiLo(), @as(i16, offset));
                },
                .LDH_A_n8 => {
                    const val: u8 = cpu.mem.read8(@as(u16, cpu.pc_pop_8()) | 0xFF00);
                    cpu.AF.setHi(val);
                },
                .LD_HL_SP_plus_n8 => {
                    const offset: i8 = @bitCast(cpu.pc_pop_8());
                    x.execAdd16Signed(cpu, &cpu.HL, Register.set, cpu.SP.getHiLo(), @as(i16, offset));
                },
            }
        } else {
            const cond: u2 = @bitCast(self.opcode);
            if (check_cond(cpu, cond)) x.execRet(cpu);
        }
    }
};

const StackRetOp = packed struct(u8) {
    _unused: u3 = 1,
    is_not_stack_op: bool,
    opcode: enum(u2) { RET = 0, RETI = 1, JP_HL = 2, LD_SP_HL = 3 },

    fn execute(self: StackRetOp, cpu: *Cpu) void {
        if (self.is_not_stack_op) {
            switch (self.opcode) {
                .RET => x.execRet(cpu),
                .RETI => {
                    x.execRet(cpu);
                    cpu.IME = true;
                },
                .JP_HL => x.execJump(cpu, cpu.HL.getHiLo()),
                .LD_SP_HL => cpu.SP.set(cpu.HL.getHiLo()), // need to fix cycles here
            }
        } else {
            const register: R16stk = @bitCast(self.opcode);
            cpu.setR16stk(register, cpu.sp_pop_16());
        }
    }
};

const JumpLoadOp = packed struct(u8) {
    _unused: u3 = 2,
    opcode: enum(u2) { LDH_C_A = 0, LD_n16_A = 1, LDH_A_C = 2, LD_A_n16 = 3 },
    is_ld: bool,
    _prefix: u2,

    fn execute(self: JumpLoadOp, cpu: *Cpu) void {
        if (self.is_ld) {
            switch (self.opcode) {
                .LDH_C_A => {
                    const addr: u16 = 0xFF00 | @as(u16, cpu.BC.getLo());
                    cpu.mem.write8(addr, cpu.AF.getHi());
                },
                .LD_n16_A => cpu.mem.write8(cpu.pc_pop_16(), cpu.AF.getHi()),
                .LDH_A_C => {
                    const addr: u16 = 0xFF00 | @as(u16, cpu.BC.getLo());
                    cpu.AF.setHi(cpu.mem.read8(addr));
                },
                .LD_A_n16 => cpu.AF.setHi(cpu.mem.read8(cpu.pc_pop_16())),
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
