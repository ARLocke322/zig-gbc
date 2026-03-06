const Bus = @import("bus.zig").Bus;
const assert = @import("std").debug.assert;
const r = @import("apu_registers.zig");

pub const Apu = @This();

bus: *Bus,

rAUD1SWEEP: r.AUD1SWEEP = .{},
rAUD1LEN: r.AUD1LEN = .{},
rAUD1ENV: r.AUD1ENV = .{},
rAUD1LOW: r.AUD1LOW = .{},
rAUD1HIGH: r.AUD1HIGH = .{},
rAUD2LEN: r.AUD2LEN = .{},
rAUD2ENV: r.AUD2ENV = .{},
rAUD2LOW: r.AUD2LOW = .{},
rAUD2HIGH: r.AUD2HIGH = .{},
rAUD3ENA: r.AUD3ENA = .{},
rAUD3LEN: r.AUD3LEN = .{},
rAUD3LEVEL: r.AUD3LEVEL = .{},
rAUD3LOW: r.AUD3LOW = .{},
rAUD3HIGH: r.AUD3HIGH = .{},
rAUD4LEN: r.AUD4LEN = .{},
rAUD4ENV: r.AUD4ENV = .{},
rAUD4POLY: r.AUD4POLY = .{},
rAUD4GO: r.AUD4GO = .{},
rAUDVOL: r.AUDVOL = .{},
rAUDTERM: r.AUDTERM = .{},
rAUDENA: r.AUDENA = .{},

CH1_volume: u4 = 0,
CH2_volume: u4 = 0,
CH4_volume: u4 = 0,

CH1_sweep_timer: u3,

CH1_envelope_timer: u3,
CH2_envelope_timer: u3,
CH4_envelope_timer: u3,

cycles: u16,
frame_sequencer_step: u3,
sample_buffer: [512 * 2]f32 = undefined,

pub fn init(bus: *Bus) Apu {
    return Apu{ .bus = bus };
}

pub fn read(self: *Apu, addr: u16) u8 {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF4F));
    return switch (addr) {
        0xFF10 => self.rAUD1SWEEP,
        0xFF11 => self.rAUD1LEN & 0xC0, // only bits 6, 7 readable
        0xFF12 => self.rAUD1ENV,
        0xFF13 => 0xFF, // write only
        0xFF14 => self.rAUD1HIGH & 0x40, // only bit 6 readable
        0xFF16 => self.rAUD2LEN,
        0xFF17 => self.rAUD2ENV,
        0xFF18 => self.rAUD2LOW,
        0xFF19 => self.rAUD2HIGH,
        0xFF1A => self.rAUD3ENA,
        0xFF1B => 0xFF, // write only
        0xFF1C => self.rAUD3LEVEL,
        0xFF1D => 0xFF, // write only
        0xFF1E => self.rAUD3HIGH & 0x40, // only bit 6 readable
        0xFF20 => 0xFF, // write only
        0xFF21 => self.rAUD4ENV,
        0xFF22 => self.rAUD4POLY,
        0xFF23 => self.rAUD4GO & 0x40, // only bit 6 readable
        0xFF24 => self.rAUDVOL,
        0xFF25 => self.rAUDTERM,
        0xFF26 => self.rAUDENA,
        else => unreachable,
    };
}

pub fn write(self: *Apu, addr: u16, val: u8) void {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF4F));
    switch (addr) {
        0xFF10 => self.rAUD1SWEEP = val,
        0xFF11 => self.rAUD1LEN = val, // only bits 6, 7 readable
        0xFF12 => self.rAUD1ENV = val,
        0xFF13 => self.rAUD1LOW = val,
        0xFF14 => self.rAUD1HIGH = val,
        0xFF16 => self.rAUD2LEN = val,
        0xFF17 => self.rAUD2ENV = val,
        0xFF18 => self.rAUD2LOW = val,
        0xFF19 => self.rAUD2HIGH = val,
        0xFF1A => self.rAUD3ENA = val,
        0xFF1B => self.rAUD3LEN = val,
        0xFF1C => self.rAUD3LEVEL = val,
        0xFF1D => self.rAUD3LOW = val, // write only
        0xFF1E => self.rAUD3HIGH = val, // only bit 6 readable
        0xFF20 => self.rAUD4LEN = val,
        0xFF21 => self.rAUD4ENV = val,
        0xFF22 => self.rAUD4POLY = val,
        0xFF23 => self.rAUD4GO = val,
        0xFF24 => self.rAUDVOL = val,
        0xFF25 => self.rAUDTERM = val,
        0xFF26 => self.rAUDENA.audio_on = @truncate(val >> 7),
        0xFF30...0xFF4F => {},
        else => unreachable,
    }
}

pub fn tick(self: *Apu, cycles: u16) void {
    self.cycles += cycles;

    while (cycles >= 8192) {
        self.cycles -= 8192;
        if (self.frame_sequencer_step % 2 == 0) { // 0, 2, 4, 6
            self.clockLength();
        }
        if (self.frame_sequencer_step == 7) {
            self.clockEnvelope();
        }
        if (self.frame_sequencer_step == 2 or self.frame_sequencer_step == 6) {
            self.clockSweep();
        }
        self.frame_sequencer_step +%= 1;
    }
}

fn clockLength(self: *Apu) void {
    if (self.rAUD1HIGH.length_enable) {
        self.rAUD1LEN.initial_length_timer +%= 1;
        if (self.rAUD1LEN.initial_length_timer == 0) self.rAUDENA.CH1_on = false;
    }
    if (self.rAUD2HIGH.length_enable) {
        self.rAUD2LEN.initial_length_timer +%= 1;
        if (self.rAUD2LEN.initial_length_timer == 0) self.rAUDENA.CH2_on = false;
    }
    if (self.rAUD3HIGH.length_enable) {
        self.rAUD3LEN.initial_length_timer +%= 1;
        if (self.rAUD3LEN.initial_length_timer == 0) self.rAUDENA.CH3_on = false;
    }
    if (self.rAUD4GO.length_enable) {
        self.rAUD4LEN.initial_length_timer +%= 1;
        if (self.rAUD4LEN.initial_length_timer == 0) self.rAUDENA.CH4_on = false;
    }
}

// Ignore for now
fn clockLengthChannel(
    length_enable: bool,
    timer: *u8,
    channel_on: *bool,
) void {
    if (length_enable) {
        timer.* +%= 1;
        if (timer.* == 0) channel_on.* = false;
    }
}

fn clockEnvelope(self: *Apu) void {
    clockEnvelopeChannel(&self.rAUD1ENV, &self.CH1_envelope_timer, &self.CH1_volume);
    clockEnvelopeChannel(&self.rAUD2ENV, &self.CH2_envelope_timer, &self.CH2_volume);
    clockEnvelopeChannel(&self.rAUD4ENV, &self.CH4_envelope_timer, &self.CH4_volume);
}

fn clockEnvelopeChannel(
    ENV: *r.ENV,
    envelope_timer: *u3,
    channel_volume: *u4,
) void {
    if (ENV.*.sweep_pace != 0) {
        envelope_timer.* -= 1;
        if (envelope_timer.* == 0) {
            envelope_timer.* = ENV.*.sweep_pace;

            if (ENV.*.env_dir == .increasing and channel_volume.* < 15)
                channel_volume.* += 1
            else if (ENV.*.env_dir == .decreasing and channel_volume.* > 0)
                channel_volume.* -= 1;
        }
    }
}

fn clockSweep(self: *Apu) void {
    const current_period: u11 =
        @as(u11, self.rAUD1HIGH.period) << 8 | self.rAUD1LOW.period;

    const step = self.rAUD1SWEEP.individual_step;

    const new_period = if (self.rAUD1SWEEP.direction == .increasing)
        @addWithOverflow(current_period, current_period >> step)
    else
        .{ current_period -| (current_period >> step), @as(u1, 0) };

    if (new_period[1] == 1) self.rAUDENA.CH1_on = false;

    if (self.rAUD1SWEEP.pace != 0) {
        self.CH1_sweep_timer -= 1;
        if (self.CH1_sweep_timer == 0) {
            self.CH1_sweep_timer = self.rAUD1SWEEP.pace;
            self.rAUD1HIGH.period = @truncate(new_period[0] >> 8);
            self.rAUD1LOW.period = @truncate(new_period[0]);
        }
    }
}
