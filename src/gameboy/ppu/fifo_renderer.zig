const Pixel = struct {
    colour: u8 = 0,
    palette: u8 = 0,
    sprite_priority: u8 = 0,
    bg_priority: u1 = 0,
};

pub const FifoRenderer = @This();

bg_fifo: [16]u8,
obj_fifo: [16]u8,

pub fn init() void {
    return .{
        .bg_fifo = Pixel{} ** 16,
        .obj_fifo = Pixel{} ** 16,
    };
}
