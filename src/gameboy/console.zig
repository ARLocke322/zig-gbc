const Cpu = @import("cpu.zig").Cpu;
const Ppu = @import("ppu.zig").Ppu;
const Bus = @import("bus.zig").Bus;
const Cartridge = @import("../cartridge/MBC1.zig").MBC1;
const Timer = @import("timer.zig").Timer;
const InterruptController = @import("interrupt_controller.zig").InterruptController;
const std = @import("std");

pub const Console = @This();

interrupt_controller: *InterruptController,
timer: *Timer,
bus: *Bus,
cpu: *Cpu,
ppu: *Ppu,

// Creates a Console struct with pointers to various components
pub fn init(
    interrupt_controller: *InterruptController,
    timer: *Timer,
    bus: *Bus,
    cpu: *Cpu,
    ppu: *Ppu,
) Console {
    return Console{
        .interrupt_controller = interrupt_controller,
        .timer = timer,
        .bus = bus,
        .cpu = cpu,
        .ppu = ppu,
    };
}

// Fetches, Decodes and Executes a single instruction, then advances
//  components by however many cycles the instruction took
// Checks if IME is scheduled and handles the interrupt after the next
//  instruction if so
// Returns cycles taken for GUI to synchronise with frames
pub fn step(
    self: *Console,
) !u16 {
    var cycles: u8 = 1; // minimum tick while halted

    // Queues interrupt to be handled after next instruction executes
    if (self.cpu.IME_scheduled) {
        self.cpu.IME = true;
        self.cpu.IME_scheduled = false;
    }

    // FDE for next instruction
    if (!self.cpu.halted) {
        const opcode = self.cpu.fetch();
        cycles = self.cpu.decode_execute(opcode);
    }

    // Services interrupt
    if (self.cpu.interrupt_controller.get_pending() != 0) {
        self.cpu.halted = false;
        if (self.cpu.IME) {
            self.cpu.handle_interrupt();
            cycles += 5;
        }
    }

    // Adds pending stall cycles from DMA to current cycle count
    const total_cycles = cycles + self.cpu.stall_cycles;
    self.cpu.stall_cycles = 0;

    // Ticks components by number of cycles taken (converted to t cycles)
    self.timer.tick(total_cycles * 4);
    self.ppu.tick(self.cpu, self.bus, total_cycles * 4);

    return total_cycles;
}

var instruction_count: u64 = 0;

// Prints Various registers for debugging
fn debugPrint(self: *Console) void {
    instruction_count += 1;
    if (instruction_count < 50) {
        const pc = self.cpu.PC.getHiLo();
        const opcode = self.cpu.mem.read8(pc);
        std.debug.print("[{d}] PC:{X:0>4} OP:{X:0>2} AF:{X:0>4} SP:{X:0>4}\n", .{
            instruction_count,     pc,                    opcode,
            self.cpu.AF.getHiLo(), self.cpu.SP.getHiLo(),
        });
    }
}
