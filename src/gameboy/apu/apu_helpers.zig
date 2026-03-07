const r = @import("apu_registers.zig");

pub fn clockEnvelopeChannel(
    ENV: *r.ENV,
    envelope_timer: *u3,
    channel_volume: *u4,
) void {
    if (ENV.*.sweep_pace != 0) {
        envelope_timer.* -%= 1;
        if (envelope_timer.* == 0) {
            envelope_timer.* = ENV.*.sweep_pace;

            if (ENV.*.env_dir == .increasing and channel_volume.* < 15)
                channel_volume.* += 1
            else if (ENV.*.env_dir == .decreasing and channel_volume.* > 0)
                channel_volume.* -= 1;
        }
    }
}
