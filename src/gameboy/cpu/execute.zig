const Cpu = @import("cpu.zig").Cpu;
const Instruction = @import("testing.zig").Instruction;
const check_cond = @import("helpers.zig").check_condition;
const R8 = @import("decode.zig").R8;
const Cb = @import("cb.zig").Cb;
const R16 = @import("decode.zig").R16;
const R16stk = @import("decode.zig").R16stk;
const R16mem = @import("decode.zig").R16mem;
const x = @import("functions.zig");

pub fn execute(cpu: *Cpu, instruction: u8) void {
    const op: Opcode = @bitCast(instruction);
    switch (instruction) {
        .NOP => NOP(cpu),
        .STOP => STOP(cpu),
        .LD_r16_n16 => LD_r16_n16(cpu, op),
        .LD_r16_A => LD_r16mem_A(cpu, op),
        .LD_A_r16 => LD_A_r16mem(cpu, op),
        .LD_n16_SP => LD_n16_SP(cpu),
        .INC_r16 => INC_r16(cpu, op),
        .DEC_r16 => DEC_r16(cpu, op),
        .ADD_HL_r16 => ADD_HL_r16(cpu, op),
        .LD_r8_n8 => LD_r8_n8(cpu, op),
        .INC_r8 => INC_r8(cpu, op),
        .DEC_r8 => DEC_r8(cpu, op),
        .RLCA => RLCA(cpu),
        .RRCA => RRCA(cpu),
        .RLA => RLA(cpu),
        .RRA => RRA(cpu),
        .DAA => DAA(cpu),
        .CPL => CPL(cpu),
        .SCF => SCF(cpu),
        .CCF => CCF(cpu),
        .JR_n8 => JR_n8(cpu),
        .JR_cond_n8 => JR_cond_n8(cpu, op),
        // BLOCK 1
        .HALT => HALT(cpu),
        .LD_r8_r8 => LD_r8_r8(cpu, op),
        // BLOCK 2
        .ADD_A_r8 => ADD_A_r8(cpu, op),
        .ADC_A_r8 => ADC_A_r8(cpu, op),
        .SUB_A_r8 => SUB_A_r8(cpu, op),
        .SBC_A_r8 => SBC_A_r8(cpu, op),
        .AND_A_r8 => AND_A_r8(cpu, op),
        .XOR_A_r8 => XOR_A_r8(cpu, op),
        .OR_A_r8 => OR_A_r8(cpu, op),
        .CP_A_r8 => CP_A_r8(cpu, op),
        // BLOCK 3
        .ADD_A_n8 => ADD_A_n8(cpu),
        .ADC_A_n8 => ADC_A_n8(cpu),
        .SUB_A_n8 => SUB_A_n8(cpu),
        .SBC_A_n8 => SBC_A_n8(cpu),
        .AND_A_n8 => AND_A_n8(cpu),
        .XOR_A_n8 => XOR_A_n8(cpu),
        .OR_A_n8 => OR_A_n8(cpu),
        .CP_A_n8 => CP_A_n8(cpu),
        .RET_cond => RET_cond(cpu, op),
        .RET => RET(cpu),
        .RETI => RETI(cpu),
        .JP_cond_n16 => JP_cond_n16(cpu, op),
        .JP_n16 => JP_n16(cpu),
        .JP_HL => JP_HL(cpu),
        .CALL_cond_n16 => CALL_cond_n16(cpu, op),
        .CALL_n16 => CALL_n16(cpu),
        .RST => RST(cpu, op),
        .POP_r16stk => POP_r16stk(cpu, op),
        .PUSH_r16stk => PUSH_r16stk(cpu, op),
        .CB_PREFIX => @as(Cb, @bitCast(cpu.pc_pop_8())).execute(cpu),
        .LDH_C_A => LDH_C_A(cpu),
        .LDH_n8_A => LDH_n8_A(cpu),
        .LD_n16_A => LD_n16_A(cpu),
        .LDH_A_C => LDH_A_C(cpu),
        .LDH_A_n8 => LDH_A_n8(cpu),
        .LD_A_n16 => LD_A_n16(cpu),
        .ADD_SP_n8 => ADD_SP_n8(cpu),
        .LD_HL_SP_n8 => LD_HL_SP_n8(cpu),
        .LD_SP_HL => LD_SP_HL(cpu),
        .DI => DI(cpu),
        .EI => EI(cpu),
    }
}

const Opcode = packed struct(u8) {
    z: u3,
    y: u3,
    x: u2,
};

fn NOP(_: *Cpu) void {}

fn STOP(_: *Cpu) void {}

fn LD_r16_n16(cpu: *Cpu, op: Opcode) void {
    const r: R16 = @enumFromInt(op.y >> 1);
    cpu.setR16(r, cpu.pc_pop_16());
}

fn LD_r16mem_A(cpu: *Cpu, op: Opcode) void {
    const r: R16mem = @enumFromInt(op.y >> 1);
    cpu.setR16mem(r, cpu.AF.getHi());
}

fn LD_A_r16mem(cpu: *Cpu, op: Opcode) void {
    const r: R16mem = @enumFromInt(op.y >> 1);
    cpu.AF.setHi(cpu.getR16mem(r));
}

fn LD_n16_SP(cpu: *Cpu) void {
    cpu.write16(cpu.pc_pop_16(), cpu.SP.getHiLo());
}

fn INC_r16(cpu: *Cpu, op: Opcode) void {
    const r: R16 = @enumFromInt(op.y >> 1);
    cpu.setR16(r, cpu.getR16(r) +% 1);
    cpu.internalCycle();
}

fn DEC_r16(cpu: *Cpu, op: Opcode) void {
    const r: R16 = @enumFromInt(op.y >> 1);
    cpu.setR16(r, cpu.getR16(r) -% 1);
    cpu.internalCycle();
}

fn ADD_HL_r16(cpu: *Cpu, op: Opcode) void {
    const r: R16 = @enumFromInt(op.y >> 1);
    x.execAdd16(cpu, cpu.HL.getHiLo(), cpu.getR16(r));
    cpu.internalCycle();
}

fn INC_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.y);
    x.execInc8(cpu, r, cpu.getR8(r));
}

fn DEC_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.y);
    x.execDec8(cpu, r, cpu.getR8(r));
}

fn LD_r8_n8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.y);
    cpu.setR8(r, cpu.pc_pop_8());
}

fn RLCA(cpu: *Cpu) void {
    x.execRotateLeft(cpu, .a, cpu.AF.getHi(), false);
    cpu.set_z(false);
}

fn RRCA(cpu: *Cpu) void {
    x.execRotateRight(cpu, .a, cpu.AF.getHi(), false);
    cpu.set_z(false);
}

fn RLA(cpu: *Cpu) void {
    x.execRotateLeft(cpu, .a, cpu.AF.getHi(), true);
    cpu.set_z(false);
}

fn RRA(cpu: *Cpu) void {
    x.execRotateRight(cpu, .a, cpu.AF.getHi(), true);
    cpu.set_z(false);
}

fn DAA(cpu: *Cpu) void {
    x.execDAA(cpu);
}

fn CPL(cpu: *Cpu) void {
    x.execCPL(cpu);
}

fn SCF(cpu: *Cpu) void {
    x.execSCF(cpu);
}

fn CCF(cpu: *Cpu) void {
    x.execCCF(cpu);
}

fn JR_n8(cpu: *Cpu) void {
    const offset: i8 = @bitCast(cpu.pc_pop_8());
    x.execJumpRelative(cpu, offset);
    cpu.tick();
}

fn JR_cond_n8(cpu: *Cpu, op: Opcode) void {
    const offset: i8 = @bitCast(cpu.pc_pop_8());
    if (check_cond(cpu, @truncate(op.y))) {
        x.execJumpRelative(cpu, offset);
        cpu.tick();
    }
}

// ===== BLOCK 1 =====

fn HALT(cpu: *Cpu) void {
    cpu.halted = true;
}

fn LD_r8_r8(cpu: *Cpu, op: Opcode) void {
    const dst: R8 = @enumFromInt(op.y);
    const src: R8 = @enumFromInt(op.z);
    cpu.setR8(dst, cpu.getR8(src));
}

// ===== BLOCK 2 =====

fn ADD_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execAdd8(cpu, .a, cpu.AF.getHi(), cpu.getR8(r), false);
}

fn ADC_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execAdd8(cpu, .a, cpu.AF.getHi(), cpu.getR8(r), true);
}

fn SUB_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execSub8(cpu, .a, cpu.AF.getHi(), cpu.getR8(r), false);
}

fn SBC_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execSub8(cpu, .a, cpu.AF.getHi(), cpu.getR8(r), true);
}

fn AND_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execAnd(cpu, .a, cpu.AF.getHi(), cpu.getR8(r));
}

fn XOR_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execXor(cpu, .a, cpu.AF.getHi(), cpu.getR8(r));
}

fn OR_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execOr(cpu, .a, cpu.AF.getHi(), cpu.getR8(r));
}

fn CP_A_r8(cpu: *Cpu, op: Opcode) void {
    const r: R8 = @enumFromInt(op.z);
    x.execCp(cpu, cpu.AF.getHi(), cpu.getR8(r));
}

// ===== BLOCK 3 =====

fn ADD_A_n8(cpu: *Cpu) void {
    x.execAdd8(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8(), false);
}

fn ADC_A_n8(cpu: *Cpu) void {
    x.execAdd8(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8(), true);
}

fn SUB_A_n8(cpu: *Cpu) void {
    x.execSub8(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8(), false);
}

fn SBC_A_n8(cpu: *Cpu) void {
    x.execSub8(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8(), true);
}

fn AND_A_n8(cpu: *Cpu) void {
    x.execAnd(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8());
}

fn XOR_A_n8(cpu: *Cpu) void {
    x.execXor(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8());
}

fn OR_A_n8(cpu: *Cpu) void {
    x.execOr(cpu, .a, cpu.AF.getHi(), cpu.pc_pop_8());
}

fn CP_A_n8(cpu: *Cpu) void {
    x.execCp(cpu, cpu.AF.getHi(), cpu.pc_pop_8());
}

fn RET_cond(cpu: *Cpu, op: Opcode) void {
    cpu.tick(); // conditional ret always burns an extra cycle
    if (check_cond(cpu, @truncate(op.y))) {
        x.execRet(cpu);
        cpu.tick();
    }
}

fn RET(cpu: *Cpu) void {
    x.execRet(cpu);
    cpu.tick();
}

fn RETI(cpu: *Cpu) void {
    x.execRet(cpu);
    cpu.tick();
    cpu.IME = true;
}

fn JP_cond_n16(cpu: *Cpu, op: Opcode) void {
    const addr = cpu.pc_pop_16();
    if (check_cond(cpu, @truncate(op.y))) {
        x.execJump(cpu, addr);
        cpu.tick();
    }
}

fn JP_n16(cpu: *Cpu) void {
    x.execJump(cpu, cpu.pc_pop_16());
    cpu.tick();
}

fn JP_HL(cpu: *Cpu) void {
    cpu.PC.set(cpu.HL.getHiLo());
}

fn CALL_cond_n16(cpu: *Cpu, op: Opcode) void {
    const addr = cpu.pc_pop_16();
    if (check_cond(cpu, @truncate(op.y))) {
        cpu.tick();
        x.execCall(cpu, addr); // push = 2 ticks
    }
}

fn CALL_n16(cpu: *Cpu) void {
    const addr = cpu.pc_pop_16();
    cpu.tick();
    x.execCall(cpu, addr);
}

fn RST(cpu: *Cpu, op: Opcode) void {
    cpu.tick();
    x.execCall(cpu, @as(u16, op.y) << 3);
}

fn POP_r16stk(cpu: *Cpu, op: Opcode) void {
    const r: R16stk = @enumFromInt(op.y >> 1);
    cpu.setR16stk(r, cpu.sp_pop_16());
}

fn PUSH_r16stk(cpu: *Cpu, op: Opcode) void {
    const r: R16stk = @enumFromInt(op.y >> 1);
    cpu.tick();
    cpu.sp_push_16(cpu.getR16stk(r));
}

fn LDH_n8_A(cpu: *Cpu) void {
    const addr: u16 = 0xFF00 | @as(u16, cpu.pc_pop_8());
    cpu.write8(addr, cpu.AF.getHi());
}

fn LDH_C_A(cpu: *Cpu) void {
    const addr: u16 = 0xFF00 | @as(u16, cpu.BC.getLo());
    cpu.write8(addr, cpu.AF.getHi());
}

fn LD_n16_A(cpu: *Cpu) void {
    cpu.write8(cpu.pc_pop_16(), cpu.AF.getHi());
}

fn LDH_A_C(cpu: *Cpu) void {
    const addr: u16 = 0xFF00 | @as(u16, cpu.BC.getLo());
    cpu.AF.setHi(cpu.read8(addr));
}

fn LDH_A_n8(cpu: *Cpu) void {
    const addr: u16 = 0xFF00 | @as(u16, cpu.pc_pop_8());
    cpu.AF.setHi(cpu.read8(addr));
}

fn LD_A_n16(cpu: *Cpu) void {
    cpu.AF.setHi(cpu.read8(cpu.pc_pop_16()));
}

fn ADD_SP_n8(cpu: *Cpu) void {
    const offset: i8 = @bitCast(cpu.pc_pop_8());
    x.execAdd16Signed(cpu, .sp, cpu.SP.getHiLo(), @as(i16, offset));
    cpu.tick();
    cpu.tick();
}

fn LD_HL_SP_n8(cpu: *Cpu) void {
    const offset: i8 = @bitCast(cpu.pc_pop_8());
    x.execAdd16Signed(cpu, .hl, cpu.SP.getHiLo(), @as(i16, offset));
    cpu.tick();
}

fn LD_SP_HL(cpu: *Cpu) void {
    cpu.SP.set(cpu.HL.getHiLo());
    cpu.tick();
}

fn DI(cpu: *Cpu) void {
    cpu.IME = false;
}

fn EI(cpu: *Cpu) void {
    cpu.IME_scheduled = true;
}
