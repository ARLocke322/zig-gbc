const r = @import("apu_registers.zig");
const clockEnvelopeChannel = @import("apu_helpers.zig").clockEnvelopeChannel;

pub const Channel4 = @This();

LEN: r.AUD4LEN = .{},
ENV: r.AUD4ENV = .{},
POLY: r.AUD4POLY = .{},
GO: r.AUD4GO = .{},

volume: u4 = 0,

envelope_timer: u3 = 0,

frequency_timer: u22 = 1,

LFSR: u16 = 0,

pub fn init() Channel4 {
    return .{};
}

pub fn handleTrigger(self: *Channel4, rAUDENA: *r.AUDENA) void {
    rAUDENA.CH4_on = true;
    const divisor: u22 = if (self.POLY.clock_divider == 0)
        8
    else
        @as(u22, self.POLY.clock_divider) * 16;
    self.frequency_timer = divisor << self.POLY.clock_shift;
    self.envelope_timer = self.ENV.sweep_pace;
    self.volume = self.ENV.initial_volume;

    self.LFSR = 0xFFFF;
}

pub fn tickFrequency(self: *Channel4) void {
    self.frequency_timer -= 1;
    if (self.frequency_timer == 0) {
        const divisor: u22 = if (self.POLY.clock_divider == 0)
            8
        else
            @as(u22, self.POLY.clock_divider) * 16;
        self.frequency_timer = divisor << self.POLY.clock_shift;
        self.tickLFSR();
    }
}

pub fn tickLFSR(self: *Channel4) void {
    const new_bit: u1 = @truncate(~(self.LFSR ^ (self.LFSR >> 1)));
    self.LFSR = (self.LFSR & 0x7FFF) | (@as(u16, new_bit) << 15);
    if (self.POLY.LFSR_width == .seven_bit) {
        self.LFSR = (self.LFSR & 0xFF7F) | (@as(u16, new_bit) << 7);
    }
    self.LFSR >>= 1;
}

pub fn clockEnvelope(self: *Channel4) void {
    clockEnvelopeChannel(&self.ENV, &self.envelope_timer, &self.volume);
}

pub fn clockSweep(self: *Channel4, rAUDENA: *r.AUDENA) void {
    const current_period: u11 = self.sweep_shadow_period;

    const step = self.SWEEP.individual_step;

    const new_period = if (self.SWEEP.direction == .increasing)
        @addWithOverflow(current_period, current_period >> step)
    else
        .{ current_period -| (current_period >> step), @as(u1, 0) };

    if (new_period[1] == 1) rAUDENA.CH1_on = false;

    if (self.SWEEP.pace != 0) {
        self.sweep_timer -%= 1;
        if (self.sweep_timer == 0) {
            self.sweep_timer = self.SWEEP.pace;
            self.HIGH.period = @truncate(new_period[0] >> 8);
            self.LOW.period = @truncate(new_period[0]);
            self.sweep_shadow_period = new_period[0];
        }
    }
}

pub fn clockLength(self: *Channel4, rAUDENA: *r.AUDENA) void {
    if (self.GO.length_enable) {
        self.LEN.initial_length_timer +%= 1;
        if (self.LEN.initial_length_timer == 0) rAUDENA.CH4_on = false;
    }
}
