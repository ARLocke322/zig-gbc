pub const LcdControl = packed struct(u8) {
    bg_window_enabled_or_sprite_priority: bool = false,
    objects_enabled: bool = false,
    object_size: enum(u1) { eight_eight = 0, eight_sixteen = 1 } = .eight_eight,
    bg_tile_map_area: u1 = 0,
    bg_window_tile_data_area: u1 = 0,
    window_enabled: bool = false,
    window_tile_map_area: u1 = 0,
    lcd_ppu_enabled: bool = false,
};

pub const LcdStatus = packed struct(u8) {
    ppu_mode: enum(u2) { hblank = 0, vblank = 1, oam_scan = 2, pixel_transfer = 4 } = .hblank,
    lyc_equals_ly: bool = false,
    mode_0_intr_selected: bool = false,
    mode_1_intr_selected: bool = false,
    mode_2_intr_selected: bool = false,
    lyc_equals_ly_intr_selected: bool = false,
    _unused: u1 = 0,
};

pub const BgMapAttributes = packed struct(u8) {
    color_palette_idx: u3 = 0,
    vram_bank: u1 = 0,
    _unused: u1 = 0,
    flipped_horizontally: bool = false,
    flipped_vertically: bool = false,
    has_priority: bool = false,
};

pub const ObjectAttribute = packed struct(u32) {
    y_position: u8 = 0,
    x_position: u8 = 0,
    tile_index: u8 = 0,
    attributes: ObjectFlags = .{},
};

const ObjectFlags = packed struct(u8) {
    cgb_palette_idx: u3 = 0,
    vram_bank: u1 = 0,
    dmg_palette_idx: u1 = 0,
    flipped_horizontally: bool = false,
    flipped_vertically: bool = false,
    bg_window_has_priority: bool = false,
};

pub const DmgBgPaletteData = packed struct(u8) {
    id_0: DmaColour = .white,
    id_1: DmaColour = .white,
    id_2: DmaColour = .white,
    id_3: DmaColour = .white,
};

pub const DmgObjectPaletteData = packed struct(u8) {
    _unused: u2 = 0,
    id_1: DmaColour = .white,
    id_2: DmaColour = .white,
    id_3: DmaColour = .white,
};

const DmaColour = enum(u2) { white, light_gray, dark_gray, black };

pub const PaletteIndex = packed struct(u8) {
    palette_address: u6 = 0,
    _unused: u1 = 0,
    auto_increment: bool = false,
};

pub const PaletteData = packed struct(u16) {
    red_intensity: u5 = 0,
    green_intensity: u5 = 0,
    blue_intensity: u5 = 0,
    _unused: u1 = 0,
};
