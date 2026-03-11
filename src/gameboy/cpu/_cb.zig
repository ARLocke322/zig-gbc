const Cpu = @import("cpu.zig").Cpu;
const helpers = @import("./cpu/helpers.zig");
const x = @import("functions.zig");

pub fn CB_PREFIX(cpu: *Cpu) u8 {
    const opcode: u8 = cpu.pc_pop_8();
    return switch (opcode) {
        0x06 => RLC_HL(cpu),
        0x00...0x05, 0x07 => RLC_r8(cpu, opcode),
        0x0E => RRC_HL(cpu),
        0x08...0x0D, 0x0F => RRC_r8(cpu, opcode),
        0x16 => RL_HL(cpu),
        0x10...0x15, 0x17 => RL_r8(cpu, opcode),
        0x1E => RR_HL(cpu),
        0x18...0x1D, 0x1F => RR_r8(cpu, opcode),
        0x26 => SLA_HL(cpu),
        0x20...0x25, 0x27 => SLA_r8(cpu, opcode),
        0x2E => SRA_HL(cpu),
        0x28...0x2D, 0x2F => SRA_r8(cpu, opcode),
        0x36 => SWAP_HL(cpu),
        0x30...0x35, 0x37 => SWAP_r8(cpu, opcode),
        0x3E => SRL_HL(cpu),
        0x38...0x3D, 0x3F => SRL_r8(cpu, opcode),
        0x46, 0x4E, 0x56, 0x5E, 0x66, 0x6E, 0x76, 0x7E => BIT_HL(cpu, opcode),

        0x40...0x45,
        0x47...0x4D,
        0x4F...0x55,
        0x57...0x5D,
        0x5F...0x65,
        0x67...0x6D,
        0x6F...0x75,
        0x77...0x7D,
        0x7F,
        => BIT_r8(cpu, opcode),

        0x86, 0x8E, 0x96, 0x9E, 0xA6, 0xAE, 0xB6, 0xBE => RES_HL(cpu, opcode),
        0x80...0x85,
        0x87...0x8D,
        0x8F...0x95,
        0x97...0x9D,
        0x9F...0xA5,
        0xA7...0xAD,
        0xAF...0xB5,
        0xB7...0xBD,
        0xBF,
        => RES_r8(cpu, opcode),

        0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE => SET_HL(cpu, opcode),
        0xC0...0xC5,
        0xC7...0xCD,
        0xCF...0xD5,
        0xD7...0xDD,
        0xDF...0xE5,
        0xE7...0xED,
        0xEF...0xF5,
        0xF7...0xFD,
        0xFF,
        => SET_r8(cpu, opcode),
    };
}

pub fn RLC_HL(cpu: *Cpu) u8 {
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current >> 7);

    const result: u8 = @as(u8, current) << 1 | new_carry;

    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);

    return 4;
}

pub fn RLC_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execRotateLeft(cpu, r.reg, r.set, r.get(r.reg), false);
    return 2;
}

pub fn RRC_HL(cpu: *Cpu) u8 {
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current);

    const result: u8 = @as(u8, new_carry) << 7 | (current >> 1);

    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);

    return 4;
}

pub fn RRC_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execRotateRight(cpu, r.reg, r.set, r.get(r.reg), false);
    return 2;
}

pub fn RL_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execRotateLeft(cpu, r.reg, r.set, r.get(r.reg), true);
    return 2;
}
pub fn RL_HL(cpu: *Cpu) u8 {
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current >> 7);

    const result: u8 = @as(u8, current) << 1 | cpu.get_c();
    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
    return 4;
}
pub fn RR_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execRotateRight(cpu, r.reg, r.set, r.get(r.reg), true);
    return 2;
}
pub fn RR_HL(cpu: *Cpu) u8 {
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current);

    const result: u8 = @as(u8, cpu.get_c()) << 7 | (current >> 1);
    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
    return 4;
}
pub fn SLA_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execArithmeticShift(cpu, r.reg, r.set, r.get(r.reg), true);
    return 2;
}
pub fn SLA_HL(cpu: *Cpu) u8 {
    const addr = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current >> 7);

    const result = current << 1;
    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
    return 4;
}
pub fn SRA_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execArithmeticShift(cpu, r.reg, r.set, r.get(r.reg), false);
    return 2;
}
pub fn SRA_HL(cpu: *Cpu) u8 {
    const addr = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current);

    const msb = current & 0x80;
    const result = (current >> 1) | msb;

    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
    return 4;
}
pub fn SWAP_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execSwap(cpu, r.reg, r.set, r.get(r.reg));
    return 2;
}
pub fn SWAP_HL(cpu: *Cpu) u8 {
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const result: u8 = (current << 4) | (current >> 4);
    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(false);

    return 4;
}
pub fn SRL_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    x.execLogicalShiftRight(cpu, r.reg, r.set, r.get(r.reg));
    return 2;
}
pub fn SRL_HL(cpu: *Cpu) u8 {
    const addr = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const new_carry: u1 = @truncate(current);

    const result = current >> 1;
    cpu.mem.write8(addr, result);

    cpu.set_z(result == 0);
    cpu.set_n(false);
    cpu.set_h(false);
    cpu.set_c(new_carry == 1);
    return 4;
}

pub fn BIT_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    const ix: u3 = @truncate(opcode >> 3);
    const test_bit: u1 = @truncate(r.get(r.reg) >> ix);
    cpu.set_z(test_bit == 0);
    cpu.set_n(false);
    cpu.set_h(true);
    return 2;
}
pub fn BIT_HL(cpu: *Cpu, opcode: u8) u8 {
    const ix: u3 = @truncate(opcode >> 3);
    const addr: u16 = cpu.HL.getHiLo();
    const test_byte: u8 = cpu.mem.read8(addr);
    const test_bit: u1 = @truncate(test_byte >> ix);

    cpu.set_z(test_bit == 0);
    cpu.set_n(false);
    cpu.set_h(true);
    return 3;
}
pub fn RES_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    const ix: u3 = @truncate(opcode >> 3);
    const current: u8 = r.get(r.reg);
    const mask: u8 = ~(@as(u8, 0x1) << ix);
    r.set(r.reg, current & mask);
    return 2;
}
pub fn RES_HL(cpu: *Cpu, opcode: u8) u8 {
    const ix: u3 = @truncate(opcode >> 3);
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const mask: u8 = ~(@as(u8, 0x1) << ix);
    cpu.mem.write8(addr, current & mask);
    return 4;
}
pub fn SET_r8(cpu: *Cpu, opcode: u8) u8 {
    const r = helpers.get_r8(cpu, @truncate(opcode));
    const ix: u3 = @truncate(opcode >> 3);
    const current: u8 = r.get(r.reg);
    const mask: u8 = @as(u8, 0x1) << ix;
    r.set(r.reg, current | mask);
    return 2;
}
pub fn SET_HL(cpu: *Cpu, opcode: u8) u8 {
    const ix: u3 = @truncate(opcode >> 3);
    const addr: u16 = cpu.HL.getHiLo();
    const current: u8 = cpu.mem.read8(addr);
    const mask: u8 = @as(u8, 0x1) << ix;
    cpu.mem.write8(addr, current | mask);
    return 4;
}
