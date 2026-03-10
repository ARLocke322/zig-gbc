const R8 = @import("decode.zig").R8;
const Cpu = @import("new_cpu.zig").Cpu;
const x = @import("new_functions.zig");

pub const Cb = packed struct(u8) {
    operand: R8,
    opcode: enum(u3) { RLC = 0, RRC = 1, RL = 2, RR = 3, SLA = 4, SRA = 5, SWAP = 6, SRL = 7 },
    prefix: enum(u2) { NORM = 0, BIT = 1, RES = 2, SET = 3 },

    fn execute(self: *Cb, cpu: *Cpu) void {
        switch (self.prefix) {
            .NORM => switch (self.opcode) {
                .RLC => x.execRotateLeft(cpu, self.operand, Cpu.set8, cpu.get8(self.operand), false),
                .RRC => x.execRotateRight(cpu, self.operand, Cpu.set8, cpu.get8(self.operand), false),
                .RL => x.execRotateLeft(cpu, self.operand, Cpu.set8, cpu.get8(self.operand), true),
                .RR => x.execRotateLeft(cpu, self.operand, Cpu.set8, cpu.get8(self.operand), true),
                .SLA => x.execArithmeticShift(cpu, self.operand, Cpu.set8, cpu.get8(self.operand), true),
                .SRA => x.execArithmeticShift(cpu, self.operand, Cpu.set8, cpu.get8(self.operand), false),
                .SWAP => x.execSwap(cpu, self.operand, Cpu.set8, cpu.get8(self.operand)),
                .SRL => x.execLogicalShiftRight(cpu, self.operand, Cpu.set8, cpu.get8(self.operand)),
            },
            .BIT => {
                const ix: u3 = @bitCast(self.opcode);
                const current: u8 = cpu.get8(self.operand);
                const test_bit: u1 = @truncate(current >> ix);

                cpu.set_z(test_bit == 0);
                cpu.set_n(false);
                cpu.set_h(true);
            },
            .RES => {
                const ix: u3 = @bitCast(self.opcode);
                const current: u8 = cpu.get8(self.operand);
                const mask: u8 = ~(@as(u8, 0x1) << ix);
                cpu.set8(self.operand, current & mask);
            },
            .SET => {
                const ix: u3 = @bitCast(self.opcode);
                const current: u8 = cpu.get8(self.operand);
                const mask: u8 = @as(u8, 0x1) << ix;
                cpu.set8(self.operand, current | mask);
            },
        }
    }
};
