const r = @import("apu_registers.zig");
const clockEnvelopeChannel = @import("apu_helpers.zig").clockEnvelopeChannel;

pub const Channel1 = @This();

SWEEP: r.AUD1SWEEP = .{},
LEN: r.AUD1LEN = .{},
ENV: r.AUD1ENV = .{},
LOW: r.AUD1LOW = .{},
HIGH: r.AUD1HIGH = .{},

volume: u4 = 0,

sweep_timer: u3 = 0,
sweep_shadow_period: u11 = 0,

envelope_timer: u3 = 0,

frequency_timer: u14 = 1,

waveform_position: u3 = 0,

pub fn init() Channel1 {
    return .{};
}

pub fn handleTrigger(self: *Channel1, rAUDENA: *r.AUDENA) void {
    rAUDENA.CH1_on = true;
    const current_period = @as(u11, self.HIGH.period) << 8 | self.LOW.period;
    self.frequency_timer = (2048 - @as(u14, current_period)) * 4;
    self.envelope_timer = self.ENV.sweep_pace;
    self.volume = self.ENV.initial_volume;
    self.sweep_timer = self.SWEEP.pace;
    self.sweep_shadow_period = current_period;

    if (self.SWEEP.individual_step != 0) {
        const delta = self.sweep_shadow_period >> self.SWEEP.individual_step;
        if (self.SWEEP.direction == .increasing) {
            const overflow_result = @addWithOverflow(self.sweep_shadow_period, delta);
            if (overflow_result[1] == 1) rAUDENA.CH1_on = false;
        }
    }
}

pub fn tickFrequency(self: *Channel1) void {
    self.frequency_timer -= 1;
    if (self.frequency_timer == 0) {
        self.frequency_timer = (2048 -
            (@as(u14, self.HIGH.period) << 8 | self.LOW.period)) * 4;
        self.waveform_position +%= 1;
    }
}

pub fn clockEnvelope(self: *Channel1) void {
    clockEnvelopeChannel(&self.ENV, &self.envelope_timer, &self.volume);
}

pub fn clockSweep(self: *Channel1, rAUDENA: *r.AUDENA) void {
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

pub fn clockLength(self: *Channel1, rAUDENA: *r.AUDENA) void {
    if (self.HIGH.length_enable) {
        self.LEN.initial_length_timer +%= 1;
        if (self.LEN.initial_length_timer == 0) rAUDENA.CH2_on = false;
    }
}
