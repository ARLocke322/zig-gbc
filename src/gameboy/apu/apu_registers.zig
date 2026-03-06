// All of the APU register types as packed structs

// --- Channel 1 ---
pub const AUD1SWEEP = packed struct(u8) {
    individual_step: u3 = 0,
    direction: enum(u1) { increasing, decreasing } = .increasing,
    pace: u3 = 0,
    _unused: u1 = 0,
};
pub const AUD1LEN = LEN;
pub const AUD1ENV = ENV;
pub const AUD1LOW = LOW;
pub const AUD1HIGH = HIGH;

// --- Channel 2 ---
pub const AUD2LEN = LEN;
pub const AUD2ENV = ENV;
pub const AUD2LOW = LOW;
pub const AUD2HIGH = HIGH;

// --- Channel 3 ---
pub const AUD3ENA = packed struct(u8) {
    _unused: u7 = 0,
    DAC_on: bool = false,
};
pub const AUD3LEN = packed struct(u8) {
    initial_length_timer: u8 = 0,
};
pub const AUD3LEVEL = packed struct(u8) {
    _unused1: u5 = 0,
    output_level: u2 = 0,
    _unused2: u1 = 0,
};
pub const AUD3LOW = LOW;
pub const AUD3HIGH = HIGH;

// --- Channel 4 ---
pub const AUD4LEN = packed struct(u8) {
    initial_length_timer: u6 = 0,
    _unused: u2 = 0,
};
pub const AUD4ENV = ENV;
pub const AUD4POLY = packed struct(u8) {
    clock_divider: u3 = 0,
    LFSR_width: enum(u1) { fifteen_bit = 0, seven_bit = 1 } = .fifteen_bit,
    clock_shift: u4 = 0,
};
pub const AUD4GO = packed struct(u8) {
    _unused: u6 = 0,
    length_enable: bool = false,
    trigger: bool = false,
};

// --- Global Control Registers ---
pub const AUDVOL = packed struct(u8) {
    right_volume: u3 = 0,
    VIN_right: bool = false,
    left_volume: u3 = 0,
    VIN_left: bool = false,
};
pub const AUDTERM = packed struct(u8) {
    CH1_right: bool = false,
    CH2_right: bool = false,
    CH3_right: bool = false,
    CH4_right: bool = false,
    CH1_left: bool = false,
    CH2_left: bool = false,
    CH3_left: bool = false,
    CH4_left: bool = false,
};
pub const AUDENA = packed struct(u8) {
    CH1_on: bool = false,
    CH2_on: bool = false,
    CH3_on: bool = false,
    CH4_on: bool = false,
    _unused: u3 = 0,
    audio_on: bool = false,
};

// --- Repeated structs ---
pub const LEN = packed struct(u8) {
    initial_length_timer: u6 = 0,
    wave_duty: u2 = 0,
};
pub const ENV = packed struct(u8) {
    sweep_pace: u3 = 0,
    env_dir: enum(u1) { decreasing, increasing } = .decreasing,
    initial_volume: u4 = 0,
};
pub const LOW = packed struct(u8) {
    period: u8 = 0,
};
pub const HIGH = packed struct(u8) {
    period: u3 = 0,
    _unused: u3 = 0,
    length_enable: bool = false,
    trigger: bool = false,
};
