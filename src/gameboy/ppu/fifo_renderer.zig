const Ppu = @import("ppu.zig");
const types = @import("ppu_types.zig");

const Pixel = struct {
    colour: u8 = 0,
    palette: u8 = 0,
    sprite_priority: u8 = 0,
    bg_priority: bool = false,
};

pub const FifoRenderer = @This();

bg_fifo: [16]Pixel,
bg_fifo_idx: u4 = 0,

obj_fifo: [16]Pixel,

state: enum { get_tile, get_tile_data_low, get_tile_data_high, sleep, push } = .get_tile,
dots: u2 = 0,
fetcher_x: u8 = 0,
fetcher_y: u8 = 0,

currently_fetching: enum { background, window, sprite } = .background,

// intermediary values
tile_idx: u8 = 0,
tile_data_address: u16 = 0,
tile_data_low: u8 = 0,
tile_data_high: u8 = 0,
tile_y: u8 = 0,
tile_flags: types.BgMapAttributes = .{},

sprite_data: types.ObjectAttribute = .{},

pub fn init() FifoRenderer {
    return .{
        .bg_fifo = [_]Pixel{.{}} ** 16,
        .obj_fifo = [_]Pixel{.{}} ** 16,
    };
}

pub fn tick(self: *FifoRenderer, ppu: *Ppu) void {
    self.dots += 1;
    switch (self.state) {
        .get_tile => self.getTile(ppu),
        .get_tile_data_low => self.getTileDataLow(ppu),
        .get_tile_data_high => self.getTileDataHigh(ppu),
        .push => self.push(),
        .sleep => self.sleep(),
    }
}

fn getTile(self: *FifoRenderer, ppu: *Ppu) void {
    if (self.dots == 2) {
        self.dots -= 2;

        const r = ppu.internal.latched;
        const lcdc = r.lcd_control;

        const tilemap_base: u16 = blk: {
            if (self.currently_fetching == .window) {
                break :blk if (lcdc.window_tile_map_area == 1) 0x9C00 else 0x9800;
            } else {
                break :blk if (lcdc.bg_tile_map_area == 1) 0x9C00 else 0x9800;
            }
        };

        const tile_x = if (self.currently_fetching == .window)
            self.fetcher_x
        else
            (@divFloor(r.scroll_x, 8) +% self.fetcher_x) & 0x1F;

        self.tile_y = if (self.currently_fetching == .window)
            self.fetcher_y
        else
            (ppu.registers.ly +% r.scroll_y) & 0xFF;

        const tilemap_addr: u16 = tilemap_base +
            (@as(u16, @divFloor(self.tile_y, 8)) * 32) +
            tile_x;

        const prev_bank = ppu.vram.bank;
        ppu.vram.bank = 0;
        self.tile_idx = ppu.read8(tilemap_addr);

        ppu.vram.bank = 1;
        self.tile_flags = @bitCast(ppu.read8(tilemap_addr));

        ppu.vram.bank = prev_bank;
        self.nextState();
    }
}

fn getTileDataLow(self: *FifoRenderer, ppu: *Ppu) void {
    if (self.dots == 2) {
        self.dots -= 2;

        const r = ppu.internal.latched;
        const lcdc = r.lcd_control;

        self.tile_data_address = blk: {
            if (self.currently_fetching == .sprite or lcdc.bg_window_tile_data_area == 1)
                break :blk 0x8000 + @as(u16, self.tile_idx) * 16;
            break :blk @as(u16, 0x9000 +% @as(i16, self.tile_idx) * 16);
        };

        const row: u16 = self.tile_y % 8;
        const row_offset: u16 = (if (self.tile_flags.flipped_vertically) 7 - row else row) * 2;

        self.tile_data_address += row_offset;

        const prev_bank = ppu.vram.bank;
        ppu.vram.bank = self.tile_flags.vram_bank;

        self.tile_data_low = ppu.read8(self.tile_data_address);

        ppu.vram.bank = prev_bank;

        self.nextState();
    }
}

fn getTileDataHigh(self: *FifoRenderer, ppu: *Ppu) void {
    if (self.dots == 2) {
        self.dots -= 2;

        const prev_bank = ppu.vram.bank;
        ppu.vram.bank = self.tile_flags.vram_bank;

        self.tile_data_high = ppu.read8(self.tile_data_address + 1);

        ppu.vram.bank = prev_bank;

        if (self.tryPush()) {
            self.fetcher_x +%= 1;
            self.state = .get_tile; // Reset to get tile step
        } else {
            self.nextState(); // proceed to Sleep
        }
    }
}

fn sleep(self: *FifoRenderer) void {
    if (self.dots == 2) {
        self.dots -= 2;
        self.nextState();
    }
}

fn push(self: *FifoRenderer) void {
    self.dots -= 1;
    if (self.tryPush()) {
        self.fetcher_x +%= 1;
        self.state = .get_tile;
    }
}

fn tryPush(self: *FifoRenderer) bool {
    if (self.bg_fifo_idx > 0) return false;
    var i: u3 = 0;
    while (i < 8) : (i += 1) {
        const bit_pos: u3 = if (self.tile_flags.flipped_horizontally) i else 7 - i;
        const colour: u2 = @intCast(((@as(u8, self.tile_data_high >> bit_pos) & 1) << 1) |
            ((@as(u8, self.tile_data_low >> bit_pos) & 1)));

        self.bg_fifo[self.bg_fifo_idx] = Pixel{
            .colour = colour,
            .bg_priority = self.tile_flags.has_priority,
            .palette = self.tile_flags.color_palette_idx,
            .sprite_priority = 0,
        };

        self.bg_fifo_idx += 1;
    }
    return true;
}

fn nextState(self: *FifoRenderer) void {
    self.state = switch (self.state) {
        .get_tile => .get_tile_data_low,
        .get_tile_data_low => .get_tile_data_high,
        .get_tile_data_high => .sleep,
        .sleep => .push,
        .push => .get_tile,
    };
}
