const Cpu = @import("../cpu.zig").Cpu;
const Register = @import("../register.zig").Register;
const Bus = @import("../bus.zig").Bus;
const R8 = @import("decode.zig").R8;
const R16 = @import("decode.zig").R16;
const R16stk = @import("decode.zig").R16stk;
const R16mem = @import("decode.zig").R16mem;
const std = @import("std");

pub fn halfCarryAdd(a: u4, b: u4, c: u1) bool {
    const hc1 = @addWithOverflow(a, b);
    const hc2 = @addWithOverflow(hc1[0], c);
    return hc1[1] == 1 or hc2[1] == 1;
}

pub fn halfCarrySub(a: u4, b: u4, c: u1) bool {
    const hc1 = @subWithOverflow(a, b);
    const hc2 = @subWithOverflow(hc1[0], c);
    return hc1[1] == 1 or hc2[1] == 1;
}

pub fn execAdd8(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    op1: u8,
    op2: u8,
    useCarry: bool,
) void {
    const carry = if (useCarry) cpu.get_c() else 0;
    const r1 = @addWithOverflow(op1, op2);
    const r2 = @addWithOverflow(r1[0], carry);

    set(cpu, dest, r2[0]);

    cpu.set_z(r2[0] == 0);
    cpu.set_n(false);
    cpu.set_h(halfCarryAdd(@truncate(op1), @truncate(op2), carry));
    cpu.set_c(r1[1] == 1 or r2[1] == 1);
}

pub fn execSub8(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    op1: u8,
    op2: u8,
    useCarry: bool,
) void {
    const carry = if (useCarry) cpu.get_c() else 0;
    const r1 = @subWithOverflow(op1, op2);
    const r2 = @subWithOverflow(r1[0], carry);

    set(cpu, dest, r2[0]);

    cpu.set_z(r2[0] == 0);
    cpu.set_n(true);
    cpu.set_h(halfCarrySub(@truncate(op1), @truncate(op2), carry));
    cpu.set_c(r1[1] == 1 or r2[1] == 1);
}

pub fn execAdd16(
    cpu: *Cpu,
    dest: R16,
    set: *const fn (*Cpu, u16) void,
    op1: u16,
    op2: u16,
) void {
    const result = @addWithOverflow(op1, op2);

    set(cpu, dest, result[0]);

    cpu.set_n(false);
    cpu.set_h(@as(u32, (op1 & 0xFFF)) + @as(u32, (op2 & 0xFFF)) > 0xFFF);
    cpu.set_c(result[1] == 1);
}

pub fn execAdd16Signed(
    cpu: *Cpu,
    dest: R16,
    set: *const fn (*Cpu, R16, u16) void,
    op1: u16,
    op2: i16,
) void {
    const op2_u16: u16 = @bitCast(op2);
    const result = @addWithOverflow(op1, op2_u16);

    set(cpu, dest, result[0]);

    cpu.set_z(false);
    cpu.set_n(false);
    cpu.set_h(halfCarryAdd(@truncate(op1), @truncate(op2_u16), 0));
    cpu.set_c((op1 & 0xFF) + (op2_u16 & 0xFF) > 0xFF);
}

pub fn execLoad16(
    cpu: *Cpu,
    dest: R16,
    set: *const fn (*Cpu, R16, u16) void,
    val: u16,
) void {
    set(cpu, dest, val);
}

pub fn execLoad16mem(
    cpu: *Cpu,
    dest: R16mem,
    set: *const fn (*Cpu, R16mem, u8) void,
    val: u8,
) void {
    set(cpu, dest, val);
}

pub fn execLoad8(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    val: u8,
) void {
    set(cpu, dest, val);
}

pub fn execInc16(
    cpu: *Cpu,
    dest: R16,
    set: *const fn (*Cpu, R16, u16) void,
    current: u16,
) void {
    set(cpu, dest, @addWithOverflow(current, 1)[0]);
}

pub fn execDec16(
    cpu: *Cpu,
    dest: R16,
    set: *const fn (*Cpu, R16, u16) void,
    current: u16,
) void {
    set(cpu, dest, @subWithOverflow(current, 1)[0]);
}

pub fn execInc8(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
) void {
    const result = @addWithOverflow(current, 1);
    set(cpu, dest, result[0]);

    cpu.set_z(result[0] == 0);
    cpu.set_n(false);
    cpu.set_h(halfCarryAdd(@truncate(current), @truncate(1), 0));
}

pub fn execDec8(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
) void {
    const result = @subWithOverflow(current, 1);

    set(cpu, dest, result[0]);

    cpu.set_z(result[0] == 0);
    cpu.set_n(true);
    cpu.set_h(halfCarrySub(@truncate(current), @truncate(1), 0));
}

pub fn execRotateLeft(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
    useCarry: bool,
) void {
    const new_carry: u1 = @truncate(current >> 7);
    const new_bit_0: u1 = if (useCarry) cpu.get_c() else new_carry;

    const result: u8 = @as(u8, current) << 1 | new_bit_0;

    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
}

pub fn execRotateRight(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
    useCarry: bool,
) void {
    const new_carry: u1 = @truncate(current);
    const new_bit_7: u1 = if (useCarry) cpu.get_c() else new_carry;

    const result: u8 = @as(u8, new_bit_7) << 7 | (current >> 1);

    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
}

pub fn execDAA(
    cpu: *Cpu,
) void {
    var adjustment: u8 = 0;
    const current: u8 = cpu.AF.getHi();
    if (cpu.get_n() == 1) {
        if (cpu.get_h() == 1) adjustment = 0x6;
        if (cpu.get_c() == 1) adjustment += 0x60;
        cpu.AF.setHi(current -% adjustment);
    } else {
        if (cpu.get_h() == 1 or (current & 0xF) > 0x9) adjustment = 0x6;
        if (cpu.get_c() == 1 or current > 0x99) {
            adjustment += 0x60;
            cpu.set_c(true);
        }
        cpu.AF.setHi(current +% adjustment);
    }

    cpu.set_z(cpu.AF.getHi() == 0);
    cpu.set_h(false);
}
pub fn execCPL(cpu: *Cpu) void {
    cpu.AF.setHi(~cpu.AF.getHi());
    cpu.set_n(true);
    cpu.set_h(true);
}
pub fn execSCF(cpu: *Cpu) void {
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(true);
}
pub fn execCCF(cpu: *Cpu) void {
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(cpu.get_c() == 0);
    return 1;
}

pub fn execJump(cpu: *Cpu, val: u16) void {
    cpu.PC.set(val);
}

pub fn execJumpRelative(cpu: *Cpu, val: i8) void {
    const new_addr: u16 = cpu.PC.getHiLo() +% @as(u16, @bitCast(@as(i16, val)));
    cpu.PC.set(new_addr);
}

pub fn execCall(cpu: *Cpu, val: u16) void {
    cpu.sp_push_16(cpu.PC.getHiLo());
    cpu.PC.set(val);
}

pub fn execRet(cpu: *Cpu) void {
    cpu.PC.set(cpu.sp_pop_16());
}

pub fn execAnd(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    op1: u8,
    op2: u8,
) void {
    const result = op1 & op2;
    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(true);
    cpu.set_c(false);
}

pub fn execXor(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    op1: u8,
    op2: u8,
) void {
    const result = op1 ^ op2;
    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(false);
}

pub fn execOr(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    op1: u8,
    op2: u8,
) void {
    const result = op1 | op2;
    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(false);
}

pub fn execCp(
    cpu: *Cpu,
    op1: u8,
    op2: u8,
) void {
    const result = @subWithOverflow(op1, op2);

    cpu.set_z(result[0] == 0);
    cpu.set_n(true);
    cpu.set_h(halfCarrySub(@truncate(op1), @truncate(op2), 0));
    cpu.set_c(result[1] == 1);
}

pub fn execArithmeticShift(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
    left: bool,
) void {
    const new_carry: u1 = if (left) @truncate(current >> 7) else @truncate(current);

    const result = if (left) current << 1 else (current >> 1) | (current & 0x80);
    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
}

pub fn execLogicalShiftRight(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
) void {
    const new_carry: u1 = @truncate(current);

    const result = current >> 1;
    set(cpu, dest, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
}
pub fn execSwap(
    cpu: *Cpu,
    dest: R8,
    set: *const fn (*Cpu, R8, u8) void,
    current: u8,
) void {
    const result: u8 = (current << 4) | (current >> 4);
    set(cpu, dest, result);
    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(false);
}
