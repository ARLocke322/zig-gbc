const R8 = @import("decode.zig").R8;
const Cpu = @import("new_cpu.zig").Cpu;
const x = @import("new_functions.zig");

pub const LdR8R8 = packed struct(u8) {
    src: u3,
    dst: u3,
    _prefix: u2 = 1,

    pub fn execute(self: *LdR8R8, cpu: *Cpu) void {
        if (self.src == 6 and self.dst == 6) { // LD HL HL = HALT
            cpu.halted = true;
        } else x.execLoad8(cpu, self.dst, Cpu.set8, cpu.get8(self.src));
    }
};
