const Ppu = @import("ppu.zig");

const Pixel = struct {
    colour: u8 = 0,
    palette: u8 = 0,
    sprite_priority: u8 = 0,
    bg_priority: bool = 0,
};

pub const FifoRenderer = @This();

bg_fifo: [16]u8,
obj_fifo: [16]u8,
state: enum { get_tile, get_tile_data_low, get_tile_data_high, sleep, push },
dots: u2,
fetcher_x: u8,
fetcher_y: u8,

scanline_x: u8,
scanline_y: u8,
currently_fetching: enum { background, window, sprite },

tile_idx: u8,

pub fn init() void {
    return .{
        .bg_fifo = Pixel{} ** 16,
        .obj_fifo = Pixel{} ** 16,
    };
}

pub fn tick(self: *FifoRenderer) void {
    if (switch (self.state) {
        .get_tile => getTile(),
        .get_tile_data_low => getTileDataLow(),
        .get_tile_data_high => getTileDataHigh(),
        .push => push(),
        .sleep => sleep(),
    }) self.next_state();
}

fn getTile(self: *FifoRenderer, ppu: *Ppu) bool {
    if (self.dots == 2) {
        self.dots -= 2;

        const r = ppu.internal.latched;
        const lcdc = r.lcd_control;

        const tilemap_base = blk: {
            if ((self.scanline_x >= r.wx - 7 and self.scanline_x < 160) and
                (lcdc.bg_window_tile_data_area == 1 or lcdc.window_tile_map_area == 1))
                break :blk 0x9C00;
            break :blk 0x9800;
        };

        const tile_x = if (self.currently_fetching == .window)
            self.fetcher_x
        else
            (@divFloor(r.scroll_x, 8) +| self.fetcher_x) & 0x1F;

        const tile_y = if (self.currently_fetching == .window)
            self.fetcher_y
        else
            (r.scroll_y +| self.fetcher_y);

        const tilemap_addr: u16 = tilemap_base +
            (@as(u16, @divFloor(tile_y, 8)) * 32) +
            tile_x;

        self.tile_idx = ppu.read8(tilemap_addr);
    }
}

fn getTileDataLow(self: *FifoRenderer) bool {
    _ = self;
}

fn getTileDataHigh(self: *FifoRenderer) bool {
    _ = self;
}

fn sleep(self: *FifoRenderer) bool {
    _ = self;
}

fn push(self: *FifoRenderer) bool {
    _ = self;
}

fn next_state(self: *FifoRenderer) void {
    self.state = switch (self.state) {
        .get_tile => .get_tile_data_low,
        .get_tile_data_low => .get_tile_data_high,
        .get_tile_data_high => .sleep,
        .sleep => .push,
        .push => .get_tile,
    };
}
