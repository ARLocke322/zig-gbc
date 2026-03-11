const execute = @import("../execute.zig").execute;
const helpers = @import("../helpers.zig");

const Register = @import("../register.zig").Register;
const Timer = @import("../timer.zig").Timer;
const Bus = @import("../bus.zig").Bus;
const Ppu = @import("../ppu.zig").Ppu;
const Apu = @import("../apu/apu.zig").Apu;
const InterruptController = @import("../interrupt_controller.zig").InterruptController;
const R8 = @import("decode.zig").R8;
const R16 = @import("decode.zig").R16;
const R16stk = @import("decode.zig").R16stk;
const R16mem = @import("decode.zig").R16mem;

// The CPU component, handles fetching, decoding, executing, and interrupt
//   servicing
pub const Cpu = @This();

// The 6 16-bit registers, accessible either as a single 16-bit register
//   or 2 8-bit registers
AF: Register,
BC: Register,
DE: Register,
HL: Register,
SP: Register,
PC: Register,

// Not used, possibly when double speed is implemented
KEY1: u8,

mem: *Bus,
timer: *Timer,
interrupt_controller: *InterruptController,
ppu: *Ppu,
apu: *Apu,

// IME_scheduled queues the interrupt for after the next instruction, IME
//   triggers the interrupt to be handled
IME: bool,
IME_scheduled: bool,

// Stores number of cycles to waste due to DMA transfers
stall_cycles: u16 = 0,

// Is the cpu halted
halted: bool,

// Initialises CPU + Register with post boot rom values
pub fn init(
    mem: *Bus,
    timer: *Timer,
    interrupt_controller: *InterruptController,
    ppu: *Ppu,
    apu: *Apu,
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
        .timer = timer,
        .ppu = ppu,
        .apu = apu,
    };
}

// Fetches a single instruction
pub fn fetch(self: *Cpu) u8 {
    return self.pc_pop_8();
}

// Decodes and executs an instruction, returns the cycles taken
pub fn decode_execute(self: *Cpu, instruction: u8) u8 {
    const cycles: u8 = execute(self, instruction);
    return cycles;
}

pub fn tick(self: *Cpu) void {
    self.timer.tick(4);
    self.ppu.tick(self, self.mem, 4);
    self.apu.tick(4);
}

pub fn read8(self: *Cpu, addr: u16) u8 {
    self.tick();
    return self.mem.read8(addr);
}

pub fn write8(self: *Cpu, addr: 16, val: u8) void {
    self.tick();
    self.mem.write8(addr, val);
}

pub fn read16(self: *Cpu, addr: u16) u16 {
    const lo = self.read8(addr);
    const hi = self.read8(addr +% 1);
    return @as(u16, hi) << 8 | lo;
}

pub fn write16(self: *Cpu, addr: u16, val: u16) void {
    self.write8(addr, @truncate(val));
    self.write8(addr +% 1, @truncate(val >> 8));
}

// Checks for pending interrupts, unhalts CPU if found, then if IME is enabled
//   services the higheset priority one, disables IME, acknowledges the
//   interrupt, pushes PC to stack and jumps to its handler vector
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
    else return;

    self.IME = false;
    self.interrupt_controller.acknowledge(interrupt_bit);
    self.sp_push_16(self.PC.getHiLo());

    const vector: u16 = 0x0040 + @as(u16, interrupt_bit) * 8;
    self.PC.set(vector);
}

// Gets the next 2 bytes in the PC and increments, used for imm16 instructions
pub fn pc_pop_16(self: *Cpu) u16 {
    const b1: u8 = self.mem.read8(self.PC.getHiLo());
    self.PC.inc();
    const b2: u8 = self.mem.read8(self.PC.getHiLo());
    self.PC.inc();
    return @as(u16, b2) << 8 | b1;
}

// Gets the next byte in the PC and increments, used for imm8 instructions
pub fn pc_pop_8(self: *Cpu) u8 {
    const b: u8 = self.mem.read8(self.PC.getHiLo());
    self.PC.inc();
    self.tick();
    return b;
}

// Pops the top 2 bytes off the stack
pub fn sp_pop_16(self: *Cpu) u16 {
    const b1: u8 = self.mem.read8(self.SP.getHiLo());
    self.SP.inc();
    const b2: u8 = self.mem.read8(self.SP.getHiLo());
    self.SP.inc();
    return @as(u16, b2) << 8 | b1;
}

// Pushes a 2 bytes onto the stack
pub fn sp_push_16(self: *Cpu, val: u16) void {
    self.SP.dec();
    self.mem.write8(self.SP.getHiLo(), @truncate(val >> 8));
    self.SP.dec();
    self.mem.write8(self.SP.getHiLo(), @truncate(val));
}

// Sets the C flag
pub fn set_c(self: *Cpu, flag: bool) void {
    const current: u8 = self.AF.getLo();
    if (flag) {
        self.AF.setLo(current | 0x10);
    } else {
        self.AF.setLo(current & ~@as(u8, 0x10));
    }
}

// Sets the H flag
pub fn set_h(self: *Cpu, flag: bool) void {
    const current: u8 = self.AF.getLo();
    if (flag) {
        self.AF.setLo(current | 0x20);
    } else {
        self.AF.setLo(current & ~@as(u8, 0x20));
    }
}

// Sets the N flag
pub fn set_n(self: *Cpu, flag: bool) void {
    const current: u8 = self.AF.getLo();
    if (flag) {
        self.AF.setLo(current | 0x40);
    } else {
        self.AF.setLo(current & ~@as(u8, 0x40));
    }
}

// Sets the Z flag
pub fn set_z(self: *Cpu, flag: bool) void {
    const current: u8 = self.AF.getLo();
    if (flag) {
        self.AF.setLo(current | 0x80);
    } else {
        self.AF.setLo(current & ~@as(u8, 0x80));
    }
}

// Gets the value of the C flag
pub fn get_c(self: *Cpu) u1 {
    return @truncate((self.AF.getLo() & 0x10) >> 4);
}

// Gets the value of the H flag
pub fn get_h(self: *Cpu) u1 {
    return @truncate((self.AF.getLo() & 0x20) >> 5);
}

// Gets the value of the N flag
pub fn get_n(self: *Cpu) u1 {
    return @truncate((self.AF.getLo() & 0x40) >> 6);
}

// Gets the value of the Z flag
pub fn get_z(self: *Cpu) u1 {
    return @truncate((self.AF.getLo() & 0x80) >> 7);
}

pub fn getR8(self: *Cpu, register: R8) u8 {
    return switch (register) {
        .b => self.BC.getHi(),
        .c => self.BC.getLo(),
        .d => self.DE.getHi(),
        .e => self.DE.getLo(),
        .h => self.HL.getHi(),
        .l => self.HL.getLo(),
        .hl => self.mem.read8(self.HL.getHiLo()),
        .a => self.AF.getHi(),
    };
}

pub fn setR8(self: *Cpu, register: R8, val: u8) void {
    switch (register) {
        .b => self.BC.setHi(val),
        .c => self.BC.setLo(val),
        .d => self.DE.setHi(val),
        .e => self.DE.setLo(val),
        .h => self.HL.setHi(val),
        .l => self.HL.setLo(val),
        .hl => self.mem.write8(self.HL.getHiLo(), val),
        .a => self.AF.setHi(val),
    }
}

pub fn getR16(self: *Cpu, register: R16) u16 {
    return switch (register) {
        .bc => self.BC.getHiLo(),
        .de => self.DE.getHiLo(),
        .hl => self.HL.getHiLo(),
        .sp => self.SP.getHiLo(),
    };
}

pub fn setR16(self: *Cpu, register: R16, val: u16) void {
    switch (register) {
        .bc => self.BC.set(val),
        .de => self.DE.set(val),
        .hl => self.HL.set(val),
        .sp => self.SP.set(val),
    }
}

pub fn setR16stk(self: *Cpu, register: R16stk, val: u16) void {
    switch (register) {
        .bc => self.BC.set(val),
        .de => self.DE.set(val),
        .hl => self.HL.set(val),
        .af => self.AF.set(val & 0xFFF0),
    }
}

pub fn getR16stk(self: *Cpu, register: R16stk) u16 {
    return switch (register) {
        .bc => self.BC.getHiLo(),
        .de => self.DE.getHiLo(),
        .hl => self.HL.getHiLo(),
        .af => self.AF.getHiLo() & 0xFFF0,
    };
}

pub fn setR16mem(self: *Cpu, register: R16mem, val: u8) void {
    switch (register) {
        .bc => self.mem.write8(self.BC.getHiLo(), val),
        .de => self.mem.write8(self.DE.getHiLo(), val),
        .hli => {
            self.mem.write8(self.HL.getHiLo(), val);
            self.HL.inc();
        },
        .hld => {
            self.mem.write8(self.HL.getHiLo(), val);
            self.HL.dec();
        },
    }
}

pub fn getR16mem(self: *Cpu, register: R16mem) u8 {
    return switch (register) {
        .bc => self.mem.read8(self.BC.getHiLo()),
        .de => self.mem.read8(self.DE.getHiLo()),
        .hli => {
            self.mem.read8(self.HL.getHiLo());
            self.HL.inc();
        },
        .hld => {
            self.mem.read8(self.HL.getHiLo());
            self.HL.dec();
        },
    };
}
