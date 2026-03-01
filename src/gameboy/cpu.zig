const std = @import("std");
const execute = @import("execute.zig").execute;
const helpers = @import("helpers.zig");

const Register = @import("register.zig").Register;
const Bus = @import("bus.zig").Bus;
const InterruptController = @import("interrupt_controller.zig").InterruptController;

pub const Cpu = struct {
    AF: Register,
    BC: Register,
    DE: Register,
    HL: Register,
    SP: Register,
    PC: Register,
    KEY1: u8,

    mem: *Bus,

    IME: bool,
    IME_scheduled: bool,

    interrupt_controller: *InterruptController,
    stall_cycles: u16 = 0,

    halted: bool,

    pub fn init(
        mem: *Bus,
        interrupt_controller: *InterruptController,
        cgb: bool,
    ) Cpu {
        return Cpu{
            .AF = Register.init(if (cgb) 0x11B0 else 0x01B0),
            .BC = Register.init(if (cgb) 0x0000 else 0x0013),
            .DE = Register.init(if (cgb) 0xFF56 else 0x00D8),
            .HL = Register.init(if (cgb) 0x000D else 0x014D),
            .SP = Register.init(0xFFFE),
            .PC = Register.init(0x0100),
            .KEY1 = 0,
            .mem = mem,
            .IME = false,
            .IME_scheduled = false,
            .interrupt_controller = interrupt_controller,
            .halted = false,
        };
    }

    pub fn fetch(self: *Cpu) u8 {
        return self.pc_pop_8();
    }

    pub fn decode_execute(self: *Cpu, instruction: u8) u8 {
        const cycles: u8 = execute(self, instruction);
        return cycles;
    }

    pub fn handle_interrupt(self: *Cpu) void {
        const pending = self.interrupt_controller.get_pending();

        if (pending != 0) self.halted = false;

        var interrupt_bit: u3 = 0;
        if (pending & 0x01 != 0) {
            interrupt_bit = 0;
        } // VBlank
        else if (pending & 0x02 != 0) {
            interrupt_bit = 1;
        } // LCD STAT
        else if (pending & 0x04 != 0) {
            interrupt_bit = 2;
        } // Timer
        else if (pending & 0x08 != 0) {
            interrupt_bit = 3;
        } // Serial
        else if (pending & 0x10 != 0) {
            interrupt_bit = 4;
        } // Joypad
        else return; // No interrupt (shouldn't happen)

        self.IME = false;
        self.interrupt_controller.acknowledge(interrupt_bit);
        self.sp_push_16(self.PC.getHiLo());

        const vector: u16 = 0x0040 + @as(u16, interrupt_bit) * 8;
        self.PC.set(vector);
    }

    pub fn pc_pop_16(self: *Cpu) u16 {
        const b1: u8 = self.mem.read8(self.PC.getHiLo());
        self.PC.inc();
        const b2: u8 = self.mem.read8(self.PC.getHiLo());
        self.PC.inc();
        return @as(u16, b2) << 8 | b1;
    }

    pub fn pc_pop_8(self: *Cpu) u8 {
        const b: u8 = self.mem.read8(self.PC.getHiLo());
        self.PC.inc();
        return b;
    }

    pub fn sp_pop_16(self: *Cpu) u16 {
        const b1: u8 = self.mem.read8(self.SP.getHiLo());
        self.SP.inc();
        const b2: u8 = self.mem.read8(self.SP.getHiLo());
        self.SP.inc();
        return @as(u16, b2) << 8 | b1;
    }

    pub fn sp_push_16(self: *Cpu, val: u16) void {
        self.SP.dec();
        self.mem.write8(self.SP.getHiLo(), @truncate(val >> 8));
        self.SP.dec();
        self.mem.write8(self.SP.getHiLo(), @truncate(val));
    }

    pub fn set_c(self: *Cpu, flag: bool) void {
        const current: u8 = self.AF.getLo();
        if (flag) {
            self.AF.setLo(current | 0x10);
        } else {
            self.AF.setLo(current & ~@as(u8, 0x10));
        }
    }

    pub fn set_h(self: *Cpu, flag: bool) void {
        const current: u8 = self.AF.getLo();
        if (flag) {
            self.AF.setLo(current | 0x20);
        } else {
            self.AF.setLo(current & ~@as(u8, 0x20));
        }
    }

    pub fn set_n(self: *Cpu, flag: bool) void {
        const current: u8 = self.AF.getLo();
        if (flag) {
            self.AF.setLo(current | 0x40);
        } else {
            self.AF.setLo(current & ~@as(u8, 0x40));
        }
    }

    pub fn set_z(self: *Cpu, flag: bool) void {
        const current: u8 = self.AF.getLo();
        if (flag) {
            self.AF.setLo(current | 0x80);
        } else {
            self.AF.setLo(current & ~@as(u8, 0x80));
        }
    }

    pub fn get_c(self: *Cpu) u1 {
        return @truncate((self.AF.getLo() & 0x10) >> 4);
    }

    pub fn get_h(self: *Cpu) u1 {
        return @truncate((self.AF.getLo() & 0x20) >> 5);
    }

    pub fn get_n(self: *Cpu) u1 {
        return @truncate((self.AF.getLo() & 0x40) >> 6);
    }

    pub fn get_z(self: *Cpu) u1 {
        return @truncate((self.AF.getLo() & 0x80) >> 7);
    }
};
