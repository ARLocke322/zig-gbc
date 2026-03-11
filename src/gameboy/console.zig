const Cpu = @import("./cpu/cpu.zig").Cpu;
const Ppu = @import("ppu.zig").Ppu;
const Bus = @import("bus.zig").Bus;
const Cartridge = @import("../cartridge/MBC1.zig").MBC1;
const Timer = @import("timer.zig").Timer;
const InterruptController = @import("interrupt_controller.zig").InterruptController;
const Apu = @import("apu/apu.zig").Apu;
const std = @import("std");

pub const Console = @This();

interrupt_controller: *InterruptController,
timer: *Timer,
bus: *Bus,
cpu: *Cpu,
ppu: *Ppu,
apu: *Apu,

const CYCLES_PER_SAMPLE: f64 = 4_194_304.0 / 48_000.0;

// Creates a Console struct with pointers to various components
pub fn init(
    interrupt_controller: *InterruptController,
    timer: *Timer,
    bus: *Bus,
    cpu: *Cpu,
    ppu: *Ppu,
    apu: *Apu,
) Console {
    return Console{
        .interrupt_controller = interrupt_controller,
        .timer = timer,
        .bus = bus,
        .cpu = cpu,
        .ppu = ppu,
        .apu = apu,
    };
}

// Fetches, Decodes and Executes a single instruction, then advances
//   components by however many cycles the instruction took
// Checks if IME is scheduled and handles the interrupt after the next
//   instruction if so
// Returns cycles taken for GUI to synchronise with frames
pub fn step(
    self: *Console,
) void {

    // Queues interrupt to be handled after next instruction executes
    if (self.cpu.IME_scheduled) {
        self.cpu.IME = true;
        self.cpu.IME_scheduled = false;
    }

    // FDE for next instruction
    if (!self.cpu.halted) {
        // self.debugPrint();
        const opcode = self.cpu.fetch();
        self.cpu.decode_execute(opcode);
    } else self.cpu.tick();

    // Services interrupt
    self.cpu.handle_interrupt();
}

pub fn stepToSample(self: *Console) void {
    self.apu.sample_ready = false;
    while (!self.apu.sample_ready) {
        self.step();
    }
}

// Prints Various registers for debugging
fn debugPrint(self: *Console) void {
    const pc = self.cpu.PC.getHiLo();
    const opcode = self.cpu.mem.read8(pc);
    std.debug.print("PC:{X:0>4} OP:{X:0>2} AF:{X:0>4} SP:{X:0>4}\n", .{
        pc,                    opcode,
        self.cpu.AF.getHiLo(), self.cpu.SP.getHiLo(),
    });
}
