const Ppu = @import("ppu.zig").Ppu;
const PALETTE: [4]u32 = .{ 0xFFE0F8D0, 0xFF88C070, 0xFF346856, 0xFF081820 };
const types = @import("ppu_types.zig");

pub fn renderScanlineCgb(ppu: *Ppu) void {
    for (0..8) |i| {
        ppu.cgb.bg_palettes[i] = getCgbPalette(ppu.cgb.bg_cram, @truncate(i));
        ppu.cgb.object_palettes[i] = getCgbPalette(ppu.cgb.object_cram, @truncate(i));
    }

    renderBackgroundCgb(ppu);
    if (ppu.internal.latched.lcd_control.window_enabled and
        ppu.registers.ly >= ppu.internal.latched.wy and
        ppu.internal.latched.wx <= 159) renderWindowCgb(ppu);
    if (ppu.internal.latched.lcd_control.objects_enabled) renderSpritesCgb(ppu);
}

fn renderBackgroundCgb(ppu: *Ppu) void {
    // starting addr of background tilemap, 2 possible regions
    const map_base: u16 = switch (ppu.internal.latched.lcd_control.bg_tile_map_area) {
        0 => 0x9800,
        1 => 0x9C00,
    };
    // starting addr of tile, 2 possible tiles
    const tile_base: u16 = switch (ppu.internal.latched.lcd_control.bg_window_tile_data_area) {
        0 => 0x9000,
        1 => 0x8000,
    };

    const use_unsigned_tiles =
        (ppu.internal.latched.lcd_control.bg_window_tile_data_area == 1);

    for (0..160) |x| {
        // absolute x and y positions with scroll
        const map_x: u8 = @as(u8, @truncate(x)) +% ppu.internal.latched.scroll_x;
        const map_y: u8 = ppu.registers.ly +% ppu.internal.latched.scroll_y;
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
    const map_base: u16 = switch (ppu.internal.latched.lcd_control.window_tile_map_area) {
        0 => 0x9800,
        1 => 0x9C00,
    };
    // starting addr of tile, 2 possible tiles
    const tile_base: u16 = switch (ppu.internal.latched.lcd_control.bg_window_tile_data_area) {
        0 => 0x9000,
        1 => 0x8000,
    };

    const use_unsigned_tiles =
        (ppu.internal.latched.lcd_control.bg_window_tile_data_area == 1);

    const window_x_start: u8 = if (ppu.internal.latched.wx > 7)
        ppu.internal.latched.wx - 7
    else
        0;

    const window_x_offset: u8 = if (ppu.internal.latched.wx >= 7)
        0
    else
        7 - ppu.internal.latched.wx;

    for (0..160) |x| {
        if (@as(u8, @truncate(x)) < window_x_start) continue;
        // absolute x, y positions in window
        const map_x: u8 = @as(u8, @truncate(x)) - window_x_start + window_x_offset;
        const map_y: u8 = ppu.internal.window_line;
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

    ppu.internal.window_line +%= 1;
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
    const prev_bank = ppu.vram.bank;
    ppu.vram.bank = 0;
    const tile_idx = ppu.read8(tilemap_addr); // e.g. we are drawing tile 4

    // calculate offset based on lcd control + tile index
    const tile_offset: i16 = if (use_unsigned_tiles)
        @as(i16, tile_idx)
    else
        @as(i8, @bitCast(tile_idx));

    // address of actual tiles pixel data, each tile is 16 bytes
    const tile_addr: u16 = tile_base +% @as(u16, @bitCast(tile_offset * 16));

    ppu.vram.bank = 1;
    const tile_flags: types.BgMapAttributes = @bitCast(ppu.read8(tilemap_addr));

    // which pixel in 8x8 tile
    var pixel_x: u8 = map_x % 8;
    var pixel_y: u8 = map_y % 8;

    if (tile_flags.flipped_horizontally) pixel_x = 7 - pixel_x;
    if (tile_flags.flipped_vertically) pixel_y = 7 - pixel_y;

    ppu.vram.bank = tile_flags.vram_bank;
    // the two bytes encoding the row of the tile
    const byte1: u8 = ppu.read8(tile_addr + pixel_y * 2);
    const byte2: u8 = ppu.read8(tile_addr + pixel_y * 2 + 1);

    ppu.vram.bank = prev_bank;

    // calculate the pixels position in this row of bytes, then get the color idx
    const bit_pos: u3 = @intCast(7 - pixel_x);
    const color_idx: u2 = @intCast(((byte1 >> bit_pos) & 1) | (((byte2 >> bit_pos) & 1) << 1));

    // const palette = getCgbPalette(ppu.bg_cram, cgb_palette);
    const palette = ppu.cgb.bg_palettes[tile_flags.color_palette_idx];
    ppu.internal.bg_idx[x] = color_idx;
    ppu.display.display_buffer[@as(u32, ppu.registers.ly) * 160 + x] = palette[color_idx];
}

fn getCgbPalette(cram: [64]u8, palette_num: u3) [4]u32 {
    var result: [4]u32 = undefined;
    const base: u8 = @as(u8, palette_num) * 8;
    for (0..4) |i| {
        const lo = cram[base + i * 2];
        const hi = cram[base + i * 2 + 1];
        const palette_data: types.CgbPaletteData = @bitCast(@as(u16, hi) << 8 | lo);
        const r5: u32 = palette_data.red_intensity;
        const g5: u32 = palette_data.green_intensity;
        const b5: u32 = palette_data.blue_intensity;
        const r: u32 = (r5 << 3) | (r5 >> 2);
        const g: u32 = (g5 << 3) | (g5 >> 2);
        const b: u32 = (b5 << 3) | (b5 >> 2);
        result[i] = 0xFF000000 | (r << 16) | (g << 8) | b;
    }
    return result;
}

fn renderSpritesCgb(ppu: *Ppu) void {
    const sprite_height: u8 = switch (ppu.internal.latched.lcd_control.object_size) {
        .eight_eight => 8,
        .eight_sixteen => 16,
    };
    // Scan OAM for sprites on this line (max 10)
    var sprites_on_line: [10]types.ObjectAttribute = undefined;
    var sprite_count: u8 = 0;
    const master_priority: bool =
        ppu.internal.latched.lcd_control.bg_window_enabled_or_sprite_priority;

    var i: u8 = 0;

    while (i < 40 and sprite_count < 10) : (i += 1) {
        const oam_addr: u16 = i;
        const sprite: types.ObjectAttribute = ppu.oam[oam_addr];
        if ((ppu.registers.ly + 16) >= sprite.y_position and
            (ppu.registers.ly + 16) < (sprite.y_position + sprite_height))
        {
            sprites_on_line[sprite_count] = sprite;
            sprite_count += 1;
        }
    }

    if (sprite_count == 0) return;
    var sprite_n = sprite_count;
    while (sprite_n != 0) {
        sprite_n -= 1;
        // calculate sprite address
        const sprite: types.ObjectAttribute = sprites_on_line[sprite_n];

        const palette = ppu.cgb.object_palettes[sprite.flags.cgb_palette_idx];

        var pixel_y: u8 = ppu.registers.ly + 16 - sprite.y_position;
        if (sprite.flags.flipped_vertically) pixel_y = (sprite_height - 1) - pixel_y;

        const masked_index: u8 = if (sprite_height == 16) sprite.tile_index & 0xFE else sprite.tile_index;
        const tile_addr: u16 = 0x8000 + @as(u16, masked_index) * 16;

        const prev_bank = ppu.vram.bank;
        ppu.vram.bank = sprite.flags.vram_bank;
        const byte1: u8 = ppu.read8(tile_addr + pixel_y * 2);
        const byte2: u8 = ppu.read8(tile_addr + pixel_y * 2 + 1);
        ppu.vram.bank = prev_bank;

        for (0..8) |px| {
            // skip if not on screen
            const result = @subWithOverflow(sprite.x_position + px, 8);
            const screen_x: u16 = @truncate(result[0]);
            if (result[1] == 1 or screen_x >= 160) continue;

            var pixel_x: u8 = @truncate(px);
            if (sprite.flags.flipped_horizontally) pixel_x = 7 - pixel_x;

            // calculate the pixels position in this row of bytes, then get the color idx
            const bit_pos: u3 = @intCast(7 - pixel_x);
            const color_idx: u2 = @intCast(((byte1 >> bit_pos) & 1) | (((byte2 >> bit_pos) & 1) << 1));

            if (color_idx == 0) continue; // transparent

            const buffer_idx = @as(u32, ppu.registers.ly) * 160 + screen_x;
            if (!sprite.flags.bg_window_has_priority or
                !master_priority or
                ppu.internal.bg_idx[screen_x] == 0)
            {
                ppu.display.display_buffer[buffer_idx] = palette[color_idx];
            }
        }
    }
}
