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

CH1_sweep_timer: u3 = 0,

CH1_envelope_timer: u3 = 0,
CH2_envelope_timer: u3 = 0,
CH4_envelope_timer: u3 = 0,

CH1_frequency_timer: u14 = 1,
CH2_frequency_timer: u14 = 1,
CH3_frequency_timer: u13 = 1,
CH4_frequency_timer: u22 = 1,

CH1_waveform_position: u3 = 0,
CH2_waveform_position: u3 = 0,
CH3_waveform_position: u5 = 0,
CH4_LFSR: u16 = 0,

cycles: u16 = 0,
sample_point_cycles: u16 = 0,
frame_sequencer_step: u3 = 0,
sample_buffer: [512 * 2]f32 = undefined,
sample_index: usize = 0,

wave_ram: [16]u8,

const duty_patterns = [4][8]u1{
    .{ 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 0, 0, 0, 0, 0, 0, 1, 1 },
    .{ 0, 0, 0, 0, 1, 1, 1, 1 },
    .{ 1, 1, 1, 1, 1, 1, 0, 0 },
};

pub fn init(bus: *Bus) Apu {
    return .{
        .bus = bus,
        .wave_ram = [_]u8{0} ** 16,
    };
}

pub fn read(self: *Apu, addr: u16) u8 {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF3F));
    return switch (addr) {
        0xFF10 => @as(u8, @bitCast(self.rAUD1SWEEP)) | 0x80,
        0xFF11 => @as(u8, @bitCast(self.rAUD1LEN)) | 0x3F, // only bits 6, 7 readable
        0xFF12 => @bitCast(self.rAUD1ENV),
        0xFF13 => 0xFF, // write only
        0xFF14 => @as(u8, @bitCast(self.rAUD1HIGH)) | 0xBF, // only bit 6 readable
        0xFF16 => @as(u8, @bitCast(self.rAUD2LEN)) | 0x3F,
        0xFF17 => @bitCast(self.rAUD2ENV),
        0xFF18 => 0xFF,
        0xFF19 => @as(u8, @bitCast(self.rAUD2HIGH)) | 0xBF,
        0xFF1A => @as(u8, @bitCast(self.rAUD3ENA)) | 0x7F,
        0xFF1B => 0xFF, // write only
        0xFF1C => @as(u8, @bitCast(self.rAUD3LEVEL)) | 0x9F,
        0xFF1D => 0xFF, // write only
        0xFF1E => @as(u8, @bitCast(self.rAUD3HIGH)) | 0xBF, // only bit 6 readable
        0xFF20 => 0xFF, // write only
        0xFF21 => @bitCast(self.rAUD4ENV),
        0xFF22 => @bitCast(self.rAUD4POLY),
        0xFF23 => @as(u8, @bitCast(self.rAUD4GO)) | 0xBF, // only bit 6 readable
        0xFF24 => @bitCast(self.rAUDVOL),
        0xFF25 => @bitCast(self.rAUDTERM),
        0xFF26 => @as(u8, @bitCast(self.rAUDENA)) | 0x70,
        0xFF30...0xFF3F => self.wave_ram[addr - 0xFF30],
        else => 0xFF,
    };
}

pub fn write(self: *Apu, addr: u16, val: u8) void {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF3F));
    switch (addr) {
        0xFF10 => self.rAUD1SWEEP = @bitCast(val),
        0xFF11 => self.rAUD1LEN = @bitCast(val),
        0xFF12 => self.rAUD1ENV = @bitCast(val),
        0xFF13 => self.rAUD1LOW = @bitCast(val),
        0xFF14 => {
            self.rAUD1HIGH = @bitCast(val);
            self.rAUDENA.CH1_on = true;
            self.CH1_frequency_timer = (2048 - self.rAUD1HIGH.period) * 4;
            self.CH1_envelope_timer = self.rAUD1ENV.sweep_pace;
            self.CH1_volume = self.rAUD1ENV.initial_volume;
            if (self.rAUD1LEN.initial_length_timer == 0)
                self.rAUD1LEN.initial_length_timer = 64;

            self.CH1_sweep_timer = self.rAUD1SWEEP.pace;
        },
        0xFF16 => self.rAUD2LEN = @bitCast(val),
        0xFF17 => self.rAUD2ENV = @bitCast(val),
        0xFF18 => self.rAUD2LOW = @bitCast(val),
        0xFF19 => {
            self.rAUD2HIGH = @bitCast(val);
            self.rAUDENA.CH2_on = true;
            self.CH2_frequency_timer = (2048 - self.rAUD2HIGH.period) * 4;
            self.CH2_envelope_timer = self.rAUD2ENV.sweep_pace;
            self.CH2_volume = self.rAUD2ENV.initial_volume;
            if (self.rAUD2LEN.initial_length_timer == 0)
                self.rAUD2LEN.initial_length_timer = 64;
        },
        0xFF1A => self.rAUD3ENA = @bitCast(val),
        0xFF1B => self.rAUD3LEN = @bitCast(val),
        0xFF1C => self.rAUD3LEVEL = @bitCast(val),
        0xFF1D => self.rAUD3LOW = @bitCast(val),
        0xFF1E => {
            self.rAUD3HIGH = @bitCast(val);
            self.rAUDENA.CH3_on = true;
            self.CH3_frequency_timer = (2048 - self.rAUD3HIGH.period) * 4;
            self.CH3_envelope_timer = self.rAUD3ENV.sweep_pace;
            self.CH3_volume = self.rAUD3ENV.initial_volume;
            if (self.rAUD3LEN.initial_length_timer == 0)
                self.rAUD3LEN.initial_length_timer = 256;

            self.CH3_waveform_position = 0;
        },
        0xFF20 => self.rAUD4LEN = @bitCast(val),
        0xFF21 => self.rAUD4ENV = @bitCast(val),
        0xFF22 => self.rAUD4POLY = @bitCast(val),
        0xFF23 => {
            self.rAUD4GO = @bitCast(val);
            self.rAUDENA.CH4_on = true;
            self.CH4_frequency_timer = (2048 - self.rAUD4HIGH.period) * 4;
            self.CH4_envelope_timer = self.rAUD4ENV.sweep_pace;
            self.CH4_volume = self.rAUD4ENV.initial_volume;
            if (self.rAUD4LEN.initial_length_timer == 0)
                self.rAUD4LEN.initial_length_timer = 256;

            self.CH4_LFSR = 0xFFFF;
        },
        0xFF24 => self.rAUDVOL = @bitCast(val),
        0xFF25 => self.rAUDTERM = @bitCast(val),
        0xFF26 => self.rAUDENA.audio_on = @truncate(val >> 7),
        0xFF30...0xFF3F => self.wave_ram[addr - 0xFF30] = val,
        else => {},
    }
}

pub fn tick(self: *Apu, cycles: u16) ?[]const f32 {
    self.cycles += cycles;
    self.sample_point_cycles += cycles;

    while (self.cycles >= 8192) {
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

    self.tickFrequencyTimers(cycles);

    while (self.sample_point_cycles >= 87) {
        self.sample_point_cycles -= 87;
        if (self.generateSample()) return &self.sample_buffer;
    }

    return null;
}

fn generateSample(self: *Apu) bool {
    var CH1_output: u4 = 0;
    var CH2_output: u4 = 0;
    var CH3_output: u4 = 0;
    var CH4_output: u4 = 0;

    if (self.rAUDENA.audio_on) {
        CH1_output = if (duty_patterns[self.rAUD1LEN.wave_duty][self.CH1_waveform_position] == 1 and
            self.rAUDENA.CH1_on)
            self.CH1_volume
        else
            0;

        CH2_output = if (duty_patterns[self.rAUD2LEN.wave_duty][self.CH2_waveform_position] == 1 and
            self.rAUDENA.CH2_on)
            self.CH2_volume
        else
            0;

        const byte: u8 = self.wave_ram[self.CH3_waveform_position >> 1]; // >> 1 = / 2, as 2 nibbles per byte
        const nibble: u4 = if (self.CH3_waveform_position & 1 == 0)
            @truncate(byte >> 4)
        else
            @truncate(byte);

        CH3_output = if (self.rAUDENA.CH3_on)
            nibble >> getOutputLevelShift(self.rAUD3LEVEL.output_level)
        else
            0;

        const LFSR_bit_0: u1 = @truncate(self.CH4_LFSR);
        CH4_output = if (LFSR_bit_0 == 0 and self.rAUDENA.CH4_on) self.CH4_volume else 0;
    }

    return self.mix(CH1_output, CH2_output, CH3_output, CH4_output);
}

fn mix(
    self: *Apu,
    CH1_output: u4,
    CH2_output: u4,
    CH3_output: u4,
    CH4_output: u4,
) bool {
    var left: u9 = 0;
    var right: u9 = 0;
    const audterm = self.rAUDTERM;

    // apply panning
    if (audterm.CH1_left) left += CH1_output;
    if (audterm.CH1_right) right += CH1_output;
    if (audterm.CH2_left) left += CH2_output;
    if (audterm.CH2_right) right += CH2_output;
    if (audterm.CH3_left) left += CH3_output;
    if (audterm.CH3_right) right += CH3_output;
    if (audterm.CH4_left) left += CH4_output;
    if (audterm.CH4_right) right += CH4_output;

    // apply master volume
    left *= (self.rAUDVOL.left_volume + 1);
    right *= (self.rAUDVOL.right_volume + 1);

    // normalise
    const normalised_left: f32 = @as(f32, @floatFromInt(left)) / 240.0 - 1.0;
    const normalised_right: f32 = @as(f32, @floatFromInt(right)) / 240.0 - 1.0;

    // combine
    self.sample_buffer[self.sample_index] = normalised_left;
    self.sample_buffer[self.sample_index + 1] = normalised_right;
    self.sample_index += 2;
    if (self.sample_index == self.sample_buffer.len) {
        self.sample_index = 0;
        return true;
    }
    return false;
}

fn getOutputLevelShift(output_level: u2) u3 {
    return switch (output_level) {
        0 => 4,
        1 => 0,
        2 => 1,
        3 => 2,
    };
}

fn tickFrequencyTimers(self: *Apu, cycles: u16) void {
    for (0..cycles) |_| {
        self.CH1_frequency_timer -= 1;
        if (self.CH1_frequency_timer == 0) {
            self.CH1_frequency_timer = (2048 -
                (@as(u14, self.rAUD1HIGH.period) << 8 | self.rAUD1LOW.period)) * 4;
            self.CH1_waveform_position +%= 1;
        }

        self.CH2_frequency_timer -= 1;
        if (self.CH2_frequency_timer == 0) {
            self.CH2_frequency_timer = (2048 -
                (@as(u14, self.rAUD2HIGH.period) << 8 | self.rAUD2LOW.period)) * 4;
            self.CH2_waveform_position +%= 1;
        }

        self.CH3_frequency_timer -= 1;
        if (self.CH3_frequency_timer == 0) {
            self.CH3_frequency_timer = (2048 -
                (@as(u13, self.rAUD3HIGH.period) << 8 | self.rAUD3LOW.period)) * 2;
            self.CH3_waveform_position +%= 1;
        }

        self.CH4_frequency_timer -= 1;
        if (self.CH4_frequency_timer == 0) {
            const divisor: u22 = if (self.rAUD4POLY.clock_divider == 0)
                8
            else
                @as(u22, self.rAUD4POLY.clock_divider) * 16;
            self.CH4_frequency_timer = divisor << self.rAUD4POLY.clock_shift;
            self.tickLFSR();
        }
    }
}

fn tickLFSR(self: *Apu) void {
    const new_bit: u1 = @truncate(~(self.CH4_LFSR ^ (self.CH4_LFSR >> 1)));
    self.CH4_LFSR = (self.CH4_LFSR & 0x7FFF) | (@as(u16, new_bit) << 15);
    if (self.rAUD4POLY.LFSR_width == .seven_bit) {
        self.CH4_LFSR = (self.CH4_LFSR & 0xFF7F) | (@as(u16, new_bit) << 7);
    }
    self.CH4_LFSR >>= 1;
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
