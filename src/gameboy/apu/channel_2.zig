const r = @import("apu_registers.zig");
const clockEnvelopeChannel = @import("apu_helpers.zig").clockEnvelopeChannel;

pub const Channel2 = @This();

LEN: r.AUD2LEN = .{},
ENV: r.AUD2ENV = .{},
LOW: r.AUD2LOW = .{},
HIGH: r.AUD2HIGH = .{},

volume: u4 = 0,

envelope_timer: u3 = 0,

frequency_timer: u14 = 1,

waveform_position: u3 = 0,

pub fn init() Channel2 {
    return .{};
}

pub fn handleTrigger(self: *Channel2, rAUDENA: *r.AUDENA) void {
    rAUDENA.CH2_on = true;
    const current_period = @as(u11, self.HIGH.period) << 8 | self.LOW.period;
    self.frequency_timer = (2048 - @as(u14, current_period)) * 4;
    self.envelope_timer = self.ENV.sweep_pace;
    self.volume = self.ENV.initial_volume;
}

pub fn tickFrequency(self: *Channel2) void {
    self.frequency_timer -= 1;
    if (self.frequency_timer == 0) {
        self.frequency_timer = (2048 -
            (@as(u14, self.HIGH.period) << 8 | self.LOW.period)) * 4;
        self.waveform_position +%= 1;
    }
}

pub fn clockEnvelope(self: *Channel2) void {
    clockEnvelopeChannel(&self.ENV, &self.envelope_timer, &self.volume);
}

pub fn clockLength(self: *Channel2, rAUDENA: *r.AUDENA) void {
    if (self.HIGH.length_enable) {
        self.LEN.initial_length_timer +%= 1;
        if (self.LEN.initial_length_timer == 0) rAUDENA.CH1_on = false;
    }
}
