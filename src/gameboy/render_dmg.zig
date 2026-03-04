const Ppu = @import("ppu.zig").Ppu;
const assert = @import("std").debug.assert;
const PALETTE: [4]u32 = .{ 0xFFE0F8D0, 0xFF88C070, 0xFF346856, 0xFF081820 };

pub fn renderScanlineDmg(ppu: *Ppu) void {
    renderBackgroundDmg(ppu);
    if ((ppu.latched_lcd_control & 0x20) != 0 and
        ppu.ly >= ppu.latched_wy and
        ppu.latched_wx <= 159) renderWindowDmg(ppu);
    if ((ppu.latched_lcd_control & 0x2) != 0) renderSpritesDmg(ppu);
}

fn renderBackgroundDmg(ppu: *Ppu) void {
    // starting addr of background tilemap, 2 possible regions
    const map_base: u16 = if ((ppu.latched_lcd_control & 0x08) != 0) 0x9C00 else 0x9800;
    // starting addr of tile, 2 possible tiles
    const tile_base: u16 = if ((ppu.latched_lcd_control & 0x10) != 0) 0x8000 else 0x9000;
    const use_unsigned_tiles = (ppu.latched_lcd_control & 0x10) != 0;

    var palette: [4]u32 = undefined;
    for (0..4) |i| {
        palette[i] = PALETTE[(ppu.latched_bgp >> @intCast(i * 2)) & 3];
    }

    for (0..160) |x| {
        // absolute x and y positions with scroll
        const map_x: u8 = @as(u8, @truncate(x)) +% ppu.latched_scx;
        const map_y: u8 = ppu.ly +% ppu.latched_scy;
        renderPixelDmg(
            ppu,
            map_base,
            tile_base,
            use_unsigned_tiles,
            palette,
            @as(u8, @truncate(x)),
            map_x,
            map_y,
        );
    }
}

fn renderWindowDmg(ppu: *Ppu) void {
    const map_base: u16 = if ((ppu.latched_lcd_control & 0x40) != 0) 0x9C00 else 0x9800;
    const tile_base: u16 = if ((ppu.latched_lcd_control & 0x10) != 0) 0x8000 else 0x9000;
    const use_unsigned_tiles = (ppu.latched_lcd_control & 0x10) != 0;
    var palette: [4]u32 = undefined;
    for (0..4) |i| {
        palette[i] = PALETTE[(ppu.latched_bgp >> @intCast(i * 2)) & 3];
    }

    const window_x_start: u8 = if (ppu.latched_wx > 7) ppu.latched_wx - 7 else 0;
    const window_x_offset: u8 = if (ppu.latched_wx >= 7) 0 else 7 - ppu.latched_wx;

    for (0..160) |x| {
        if (@as(u8, @truncate(x)) < window_x_start) continue;
        // absolute x, y positions in window
        const map_x: u8 = @as(u8, @truncate(x)) - window_x_start + window_x_offset;
        const map_y: u8 = ppu.window_line;
        renderPixelDmg(
            ppu,
            map_base,
            tile_base,
            use_unsigned_tiles,
            palette,
            @as(u8, @truncate(x)),
            map_x,
            map_y,
        );
    }

    ppu.window_line +%= 1;
}

fn renderPixelDmg(
    ppu: *Ppu,
    map_base: u16,
    tile_base: u16,
    use_unsigned_tiles: bool,
    palette: [4]u32,
    x: u8,
    map_x: u8,
    map_y: u8,
) void {
    // which tile the pixel falls in
    const tile_x: u8 = @divFloor(map_x, 8);
    const tile_y: u8 = @divFloor(map_y, 8);

    // calculate tile index address and read it
    const tilemap_addr: u16 = map_base + @as(u16, tile_y) * 32 + tile_x;
    const tile_idx = ppu.read8(tilemap_addr); // e.g. we are drawing tile 4

    // calculate offset based on lcd control + tile index
    const tile_offset: i16 = if (use_unsigned_tiles)
        @as(i16, tile_idx)
    else
        @as(i8, @bitCast(tile_idx));

    // address of actual tiles pixel data, each tile is 16 bytes
    const tile_addr: u16 = tile_base +% @as(u16, @bitCast(tile_offset * 16));

    // which pixel in 8x8 tile
    const pixel_x: u8 = map_x % 8;
    const pixel_y: u8 = map_y % 8;

    // the two bytes encoding the row of the tile
    const byte1: u8 = ppu.read8(tile_addr + pixel_y * 2);
    const byte2: u8 = ppu.read8(tile_addr + pixel_y * 2 + 1);

    // calculate the pixels position in this row of bytes, then get the color idx
    const bit_pos: u3 = @intCast(7 - pixel_x);
    const color_idx: u2 = @intCast(((byte1 >> bit_pos) & 1) | (((byte2 >> bit_pos) & 1) << 1));

    ppu.display_buffer[@as(u32, ppu.ly) * 160 + x] = palette[color_idx];
}

fn renderSpritesDmg(ppu: *Ppu) void {
    const sprite_height: u8 = if ((ppu.latched_lcd_control & 0x04) != 0) 16 else 8;
    // Scan OAM for sprites on this line (max 10)
    var sprites_on_line: [10]u8 = undefined;
    var sprite_count: u8 = 0;
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
        const dmg_palette: u1 = @truncate(sprite_flags >> 4);

        var palette: [4]u32 = undefined;
        const palette_data = if (dmg_palette == 0) ppu.latched_obp0 else ppu.latched_obp1;
        for (0..4) |p| {
            palette[p] = PALETTE[(palette_data >> @intCast(p * 2)) & 3];
        }

        var pixel_y: u8 = ppu.ly + 16 - sprite_y;
        if (y_flip == 1) pixel_y = (sprite_height - 1) - pixel_y;

        const tile_addr: u16 = 0x8000 + tile_idx * 16;
        const byte1: u8 = ppu.read8(tile_addr + pixel_y * 2);
        const byte2: u8 = ppu.read8(tile_addr + pixel_y * 2 + 1);

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
            if (priority == 0 or ppu.display_buffer[buffer_idx] == palette[0]) {
                ppu.display_buffer[buffer_idx] = palette[color_idx];
            }
        }
    }
}
