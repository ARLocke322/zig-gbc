const assert = @import("std").debug.assert;
const std = @import("std");
const r = @import("apu_registers.zig");
const Channel1 = @import("channel_1.zig").Channel1;
const Channel2 = @import("channel_2.zig").Channel2;
const Channel3 = @import("channel_3.zig").Channel3;
const Channel4 = @import("channel_4.zig").Channel4;
pub const Apu = @This();

rAUDVOL: r.AUDVOL = .{},
rAUDTERM: r.AUDTERM = .{},
rAUDENA: r.AUDENA = .{},

cycles: u16 = 0,
sample_point_cycles: u16 = 0,
frame_sequencer_step: u3 = 0,
sample_buffer: [512 * 2]f32 = undefined,
sample_index: usize = 0,

wave_ram: [16]u8,

sample_ready: bool = false,

channel_1: *Channel1,
channel_2: *Channel2,
channel_3: *Channel3,
channel_4: *Channel4,

const duty_patterns = [4][8]u1{
    .{ 0, 0, 0, 0, 0, 0, 0, 1 },
    .{ 0, 0, 0, 0, 0, 0, 1, 1 },
    .{ 0, 0, 0, 0, 1, 1, 1, 1 },
    .{ 1, 1, 1, 1, 1, 1, 0, 0 },
};

pub fn init(
    channel_1: *Channel1,
    channel_2: *Channel2,
    channel_3: *Channel3,
    channel_4: *Channel4,
) Apu {
    return .{
        .channel_1 = channel_1,
        .channel_2 = channel_2,
        .channel_3 = channel_3,
        .channel_4 = channel_4,
        .wave_ram = [_]u8{0} ** 16,
    };
}

pub fn read(self: *Apu, addr: u16) u8 {
    assert((addr >= 0xFF10 and addr <= 0xFF26) or
        (addr >= 0xFF30 and addr <= 0xFF3F));
    return switch (addr) {
        0xFF10 => @as(u8, @bitCast(self.channel_1.SWEEP)) | 0x80,
        0xFF11 => @as(u8, @bitCast(self.channel_1.LEN)) | 0x3F, // only bits 6, 7 readable
        0xFF12 => @bitCast(self.channel_1.ENV),
        0xFF13 => 0xFF, // write only
        0xFF14 => @as(u8, @bitCast(self.channel_1.HIGH)) | 0xBF, // only bit 6 readable
        0xFF16 => @as(u8, @bitCast(self.channel_2.LEN)) | 0x3F,
        0xFF17 => @bitCast(self.channel_2.ENV),
        0xFF18 => 0xFF,
        0xFF19 => @as(u8, @bitCast(self.channel_2.HIGH)) | 0xBF,
        0xFF1A => @as(u8, @bitCast(self.channel_3.ENA)) | 0x7F,
        0xFF1B => 0xFF, // write only
        0xFF1C => @as(u8, @bitCast(self.channel_3.LEVEL)) | 0x9F,
        0xFF1D => 0xFF, // write only
        0xFF1E => @as(u8, @bitCast(self.channel_3.HIGH)) | 0xBF, // only bit 6 readable
        0xFF20 => 0xFF, // write only
        0xFF21 => @bitCast(self.channel_4.ENV),
        0xFF22 => @bitCast(self.channel_4.POLY),
        0xFF23 => @as(u8, @bitCast(self.channel_4.GO)) | 0xBF, // only bit 6 readable
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
        0xFF10 => self.channel_1.SWEEP = @bitCast(val),
        0xFF11 => self.channel_1.LEN = @bitCast(val),
        0xFF12 => self.channel_1.ENV = @bitCast(val),
        0xFF13 => self.channel_1.LOW = @bitCast(val),
        0xFF14 => {
            self.channel_1.HIGH = @bitCast(val);
            if (self.channel_1.HIGH.trigger) {
                self.channel_1.handleTrigger(&self.rAUDENA);
            }
        },
        0xFF16 => self.channel_2.LEN = @bitCast(val),
        0xFF17 => self.channel_2.ENV = @bitCast(val),
        0xFF18 => self.channel_2.LOW = @bitCast(val),
        0xFF19 => {
            self.channel_2.HIGH = @bitCast(val);
            if (self.channel_2.HIGH.trigger) {
                self.channel_2.handleTrigger(&self.rAUDENA);
            }
        },
        0xFF1A => self.channel_3.ENA = @bitCast(val),
        0xFF1B => self.channel_3.LEN = @bitCast(val),
        0xFF1C => self.channel_3.LEVEL = @bitCast(val),
        0xFF1D => self.channel_3.LOW = @bitCast(val),
        0xFF1E => {
            self.channel_3.HIGH = @bitCast(val);
            if (self.channel_3.HIGH.trigger) {
                self.channel_3.handleTrigger(&self.rAUDENA);
            }
        },
        0xFF20 => self.channel_4.LEN = @bitCast(val),
        0xFF21 => self.channel_4.ENV = @bitCast(val),
        0xFF22 => self.channel_4.POLY = @bitCast(val),
        0xFF23 => {
            self.channel_4.GO = @bitCast(val);
            if (self.channel_4.GO.trigger) {
                self.channel_4.handleTrigger(&self.rAUDENA);
            }
        },
        0xFF24 => self.rAUDVOL = @bitCast(val),
        0xFF25 => self.rAUDTERM = @bitCast(val),
        0xFF26 => self.rAUDENA.audio_on = (val >> 7) & 1 == 1,
        0xFF30...0xFF3F => self.wave_ram[addr - 0xFF30] = val,
        else => {},
    }
}

pub fn tick(self: *Apu, cycles: u16) void {
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
            self.channel_1.clockSweep(&self.rAUDENA);
        }
        self.frame_sequencer_step +%= 1;
    }

    self.tickFrequencyTimers(cycles);

    while (self.sample_point_cycles >= 87) {
        self.sample_point_cycles -= 87;
        if (self.generateSample()) {
            self.sample_ready = true;
            return;
        }
    }
}

fn generateSample(self: *Apu) bool {
    var CH1_output: u4 = 0;
    var CH2_output: u4 = 0;
    var CH3_output: u4 = 0;
    var CH4_output: u4 = 0;

    if (self.rAUDENA.audio_on) {
        CH1_output = if (duty_patterns[self.channel_1.LEN.wave_duty][self.channel_1.waveform_position] == 1 and
            self.rAUDENA.CH1_on)
            self.channel_1.volume
        else
            0;

        CH2_output = if (duty_patterns[self.channel_2.LEN.wave_duty][self.channel_2.waveform_position] == 1 and
            self.rAUDENA.CH2_on)
            self.channel_2.volume
        else
            0;

        const byte: u8 = self.wave_ram[self.channel_3.waveform_position >> 1]; // >> 1 = / 2, as 2 nibbles per byte
        const nibble: u4 = if (self.channel_3.waveform_position & 1 == 0)
            @truncate(byte >> 4)
        else
            @truncate(byte);

        CH3_output = if (self.rAUDENA.CH3_on)
            getCH3Sample(nibble, self.channel_3.LEVEL.output_level)
        else
            0;

        const LFSR_bit_0: u1 = @truncate(self.channel_4.LFSR);
        CH4_output = if (LFSR_bit_0 == 0 and self.rAUDENA.CH4_on) self.channel_4.volume else 0;
    }

    return self.mix(CH1_output, CH2_output, CH3_output, CH4_output);
}
fn getCH3Sample(nibble: u4, output_level: u2) u4 {
    return switch (output_level) {
        0 => 0,
        1 => nibble,
        2 => nibble >> 1,
        3 => nibble >> 2,
    };
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
    left *= (@as(u9, self.rAUDVOL.left_volume) + 1);
    right *= (@as(u9, self.rAUDVOL.right_volume) + 1);

    // normalise
    const normalised_left: f32 = @as(f32, @floatFromInt(left)) / 480.0;
    const normalised_right: f32 = @as(f32, @floatFromInt(right)) / 480.0;

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

fn tickFrequencyTimers(self: *Apu, cycles: u16) void {
    for (0..cycles) |_| {
        self.channel_1.tickFrequency();
        self.channel_2.tickFrequency();
        self.channel_3.tickFrequency();
        self.channel_4.tickFrequency();
    }
}

fn clockLength(self: *Apu) void {
    self.channel_1.clockLength(&self.rAUDENA);
    self.channel_2.clockLength(&self.rAUDENA);
    self.channel_3.clockLength(&self.rAUDENA);
    self.channel_4.clockLength(&self.rAUDENA);
}

fn clockEnvelope(self: *Apu) void {
    self.channel_1.clockEnvelope();
    self.channel_2.clockEnvelope();
    self.channel_4.clockEnvelope();
}
