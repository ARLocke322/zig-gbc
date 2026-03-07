const r = @import("apu_registers.zig");
const clockEnvelopeChannel = @import("apu_helpers.zig").clockEnvelopeChannel;

pub const Channel3 = @This();

ENA: r.AUD3ENA = .{},
LEN: r.AUD3LEN = .{},
LEVEL: r.AUD3LEVEL = .{},
LOW: r.AUD3LOW = .{},
HIGH: r.AUD3HIGH = .{},

frequency_timer: u13 = 1,

waveform_position: u5 = 0,

pub fn init() Channel3 {
    return .{};
}

pub fn handleTrigger(self: *Channel3, rAUDENA: *r.AUDENA) void {
    rAUDENA.CH3_on = true;
    const current_period = @as(u11, self.HIGH.period) << 8 | self.LOW.period;
    self.frequency_timer = (2048 - @as(u13, current_period)) * 2;
    self.waveform_position = 0;
}

pub fn tickFrequency(self: *Channel3) void {
    self.frequency_timer -= 1;
    if (self.frequency_timer == 0) {
        self.frequency_timer = (2048 -
            (@as(u13, self.HIGH.period) << 8 | self.LOW.period)) * 2;
        self.waveform_position +%= 1;
    }
}

pub fn clockLength(self: *Channel3, rAUDENA: *r.AUDENA) void {
    if (self.HIGH.length_enable) {
        self.LEN.initial_length_timer +%= 1;
        if (self.LEN.initial_length_timer == 0) rAUDENA.CH3_on = false;
    }
}
