const Ppu = @import("ppu.zig").Ppu;
const assert = @import("std").debug.assert;
const PALETTE: [4]u32 = .{ 0xFFE0F8D0, 0xFF88C070, 0xFF346856, 0xFF081820 };

pub fn renderScanlineCgb(ppu: *Ppu) void {
    for (0..8) |i| {
        ppu.bg_palettes[i] = getCgbPalette(ppu.bg_cram, @intCast(i));
        ppu.obj_palettes[i] = getCgbPalette(ppu.obj_cram, @intCast(i));
    }
    ppu.bg_idx = .{0} ** 160;
    renderBackgroundCgb(ppu);
    if ((ppu.latched_lcd_control & 0x20) != 0 and
        ppu.ly >= ppu.latched_wy and
        ppu.latched_wx <= 159) renderWindowCgb(ppu);
    if ((ppu.latched_lcd_control & 0x2) != 0) renderSpritesCgb(ppu);
}

fn renderBackgroundCgb(ppu: *Ppu) void {
    // starting addr of background tilemap, 2 possible regions
    const map_base: u16 = if ((ppu.latched_lcd_control & 0x08) != 0) 0x9C00 else 0x9800;
    // starting addr of tile, 2 possible tiles
    const tile_base: u16 = if ((ppu.latched_lcd_control & 0x10) != 0) 0x8000 else 0x9000;
    const use_unsigned_tiles = (ppu.latched_lcd_control & 0x10) != 0;

    for (0..160) |x| {
        // absolute x and y positions with scroll
        const map_x: u8 = @as(u8, @truncate(x)) +% ppu.latched_scx;
        const map_y: u8 = ppu.ly +% ppu.latched_scy;
        renderPixelCgb(
            ppu,
            map_base,
            tile_base,
            use_unsigned_tiles,
            @as(u8, @truncate(x)),
            map_x,
            map_y,
        );
    }
}

fn renderWindowCgb(ppu: *Ppu) void {
    const map_base: u16 = if ((ppu.latched_lcd_control & 0x40) != 0) 0x9C00 else 0x9800;
    const tile_base: u16 = if ((ppu.latched_lcd_control & 0x10) != 0) 0x8000 else 0x9000;
    const use_unsigned_tiles = (ppu.latched_lcd_control & 0x10) != 0;

    const window_x_start: u8 = if (ppu.latched_wx > 7) ppu.latched_wx - 7 else 0;
    const window_x_offset: u8 = if (ppu.latched_wx >= 7) 0 else 7 - ppu.latched_wx;

    for (0..160) |x| {
        if (@as(u8, @truncate(x)) < window_x_start) continue;
        // absolute x, y positions in window
        const map_x: u8 = @as(u8, @truncate(x)) - window_x_start + window_x_offset;
        const map_y: u8 = ppu.window_line;
        renderPixelCgb(
            ppu,
            map_base,
            tile_base,
            use_unsigned_tiles,
            @as(u8, @truncate(x)),
            map_x,
            map_y,
        );
    }

    ppu.window_line +%= 1;
}

fn renderPixelCgb(
    ppu: *Ppu,
    map_base: u16,
    tile_base: u16,
    use_unsigned_tiles: bool,
    x: u8,
    map_x: u8,
    map_y: u8,
) void {
    // which tile the pixel falls in
    const tile_x: u8 = @divFloor(map_x, 8);
    const tile_y: u8 = @divFloor(map_y, 8);

    // calculate tile index address and read it
    const tilemap_addr: u16 = map_base + @as(u16, tile_y) * 32 + tile_x;
    const prev_bank = ppu.vram_bank;
    ppu.vram_bank = 0;
    const tile_idx = ppu.read8(tilemap_addr); // e.g. we are drawing tile 4

    // calculate offset based on lcd control + tile index
    const tile_offset: i16 = if (use_unsigned_tiles)
        @as(i16, tile_idx)
    else
        @as(i8, @bitCast(tile_idx));

    // address of actual tiles pixel data, each tile is 16 bytes
    const tile_addr: u16 = tile_base +% @as(u16, @bitCast(tile_offset * 16));

    ppu.vram_bank = 1;
    const tile_flags = ppu.read8(tilemap_addr);

    const y_flip: u1 = @truncate(tile_flags >> 6);
    const x_flip: u1 = @truncate(tile_flags >> 5);
    const tile_bank: u1 = @truncate(tile_flags >> 3);
    const cgb_palette: u3 = @truncate(tile_flags);

    // which pixel in 8x8 tile
    var pixel_x: u8 = map_x % 8;
    var pixel_y: u8 = map_y % 8;

    if (x_flip == 1) pixel_x = 7 - pixel_x;
    if (y_flip == 1) pixel_y = 7 - pixel_y;

    ppu.vram_bank = tile_bank;
    // the two bytes encoding the row of the tile
    const byte1: u8 = ppu.read8(tile_addr + pixel_y * 2);
    const byte2: u8 = ppu.read8(tile_addr + pixel_y * 2 + 1);

    ppu.vram_bank = prev_bank;

    // calculate the pixels position in this row of bytes, then get the color idx
    const bit_pos: u3 = @intCast(7 - pixel_x);
    const color_idx: u2 = @intCast(((byte1 >> bit_pos) & 1) | (((byte2 >> bit_pos) & 1) << 1));

    // const palette = getCgbPalette(ppu.bg_cram, cgb_palette);
    const palette = ppu.bg_palettes[cgb_palette];
    ppu.bg_idx[x] = color_idx;
    ppu.display_buffer[@as(u32, ppu.ly) * 160 + x] = palette[color_idx];
}

fn getCgbPalette(cram: [64]u8, palette_index: u3) [4]u32 {
    var result: [4]u32 = undefined;
    const base = @as(usize, palette_index) * 8;
    for (0..4) |i| {
        const lo = cram[base + i * 2];
        const hi = cram[base + i * 2 + 1];
        const rgb555 = @as(u16, hi) << 8 | lo;
        const r5: u32 = rgb555 & 0x1F;
        const g5: u32 = (rgb555 >> 5) & 0x1F;
        const b5: u32 = (rgb555 >> 10) & 0x1F;
        const r: u32 = (r5 << 3) | (r5 >> 2);
        const g: u32 = (g5 << 3) | (g5 >> 2);
        const b: u32 = (b5 << 3) | (b5 >> 2);
        result[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
    }
    return result;
}

fn renderSpritesCgb(ppu: *Ppu) void {
    const sprite_height: u8 = if ((ppu.latched_lcd_control & 0x04) != 0) 16 else 8;
    // Scan OAM for sprites on this line (max 10)
    var sprites_on_line: [10]u8 = undefined;
    var sprite_count: u8 = 0;
    const master_priority: bool = (ppu.latched_lcd_control & 0x01) != 0;
    var i: u8 = 0;

    while (i < 40 and sprite_count < 10) : (i += 1) {
        const oam_addr: u16 = i * 4;
        const sprite_y: u8 = ppu.oam[oam_addr];
        if ((ppu.ly + 16) >= sprite_y and (ppu.ly + 16) < (sprite_y + sprite_height)) {
            sprites_on_line[sprite_count] = i;
            sprite_count += 1;
        }
    }

    if (sprite_count == 0) return;
    var sprite_n = sprite_count;
    while (sprite_n != 0) {
        sprite_n -= 1;
        // calculate sprite address
        const sprite_idx: u8 = sprites_on_line[sprite_n];
        const sprite_addr: u16 = sprite_idx * 4;

        // break down 4 byte sprite information
        const sprite_y: u8 = ppu.oam[sprite_addr];
        const sprite_x: u8 = ppu.oam[sprite_addr + 1];
        const tile_idx: u16 = ppu.oam[sprite_addr + 2];
        const sprite_flags: u8 = ppu.oam[sprite_addr + 3];

        const priority: u1 = @truncate(sprite_flags >> 7);
        const y_flip: u1 = @truncate(sprite_flags >> 6);
        const x_flip: u1 = @truncate(sprite_flags >> 5);
        const bank: u1 = @truncate(sprite_flags >> 3);
        const cgb_palette: u3 = @truncate(sprite_flags);

        // const palette = getCgbPalette(ppu.obj_cram, cgb_palette);
        const palette = ppu.obj_palettes[cgb_palette];

        var pixel_y: u8 = ppu.ly + 16 - sprite_y;
        if (y_flip == 1) pixel_y = (sprite_height - 1) - pixel_y;

        const tile_addr: u16 = 0x8000 + tile_idx * 16;
        const prev_bank = ppu.vram_bank;
        ppu.vram_bank = bank;
        const byte1: u8 = ppu.read8(tile_addr + pixel_y * 2);
        const byte2: u8 = ppu.read8(tile_addr + pixel_y * 2 + 1);
        ppu.vram_bank = prev_bank;

        for (0..8) |px| {
            // skip if not on screen
            const result = @subWithOverflow(sprite_x + px, 8);
            const screen_x: u16 = @truncate(result[0]);
            if (result[1] == 1 or screen_x >= 160) continue;

            var pixel_x: u8 = @truncate(px);
            if (x_flip == 1) pixel_x = 7 - pixel_x;

            // calculate the pixels position in this row of bytes, then get the color idx
            const bit_pos: u3 = @intCast(7 - pixel_x);
            const color_idx: u2 = @intCast(((byte1 >> bit_pos) & 1) | (((byte2 >> bit_pos) & 1) << 1));

            if (color_idx == 0) continue; // transparent

            const buffer_idx = @as(u32, ppu.ly) * 160 + screen_x;
            if (priority == 0 or !master_priority or ppu.bg_idx[screen_x] == 0) {
                ppu.display_buffer[buffer_idx] = palette[color_idx];
            }
        }
    }
}
