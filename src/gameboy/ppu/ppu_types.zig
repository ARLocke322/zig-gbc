// PPU specific structs for state + memory
pub const Vram = struct {
    tile_data: [0x1800 * 2]u8 = [_]u8{0} ** (0x1800 * 2), // 0x1800 * 2 banks
    tile_map_1: [0x400 * 2]u8 = [_]u8{0} ** (0x400 * 2), // 0x400 * 2 banks
    tile_map_2: [0x400 * 2]u8 = [_]u8{0} ** (0x400 * 2), // 0x400 * 2 banks
    bank: u1 = 0,
};

pub const Registers = struct {
    lcd_control: LcdControl = .{},
    stat: LcdStatus = .{},

    scroll_y: u8 = 0,
    scroll_x: u8 = 0,

    ly: u8 = 0,
    lyc: u8 = 0,

    dma: u8 = 0,

    wy: u8 = 0, // FF4A
    wx: u8 = 0, // FF4B
};

pub const DmgState = struct {
    bg_palette_data: DmgBgPaletteData = .{},
    object_palette_0_data: DmgObjectPaletteData = .{},
    object_palette_1_data: DmgObjectPaletteData = .{},
};

pub const CgbState = struct {
    enabled: bool = false,

    bg_palette_idx: CgbPaletteIndex = .{},
    object_palette_idx: CgbPaletteIndex = .{},

    bg_cram: [64]u8 = [_]u8{0} ** 64,
    object_cram: [64]u8 = [_]u8{0} ** 64,

    bg_palettes: [8][4]u32 = [_][4]u32{[_]u32{0xFFFFFFFF} ** 4} ** 8,
    object_palettes: [8][4]u32 = [_][4]u32{[_]u32{0xFFFFFFFF} ** 4} ** 8,

    object_priority_mode: enum(u1) { CGB, DMG } = .CGB,
};

pub const InternalState = struct {
    cycles: u16 = 0,
    window_line: u8 = 0,
    current_signal: bool = false,
    stat_int_signal: bool = false,

    bg_idx: [160]u2 = [_]u2{0} ** 160,

    latched: Latched = .{},

    const Latched = struct {
        scroll_x: u8 = 0,
        scroll_y: u8 = 0,
        dmg_bg_palette_data: DmgBgPaletteData = .{},
        dmg_object_palette_0_data: DmgObjectPaletteData = .{},
        dmg_object_palette_1_data: DmgObjectPaletteData = .{},
        lcd_control: LcdControl = .{},
        wy: u8 = 0,
        wx: u8 = 0,
    };
};

pub const DisplayState = struct {
    display_buffer: [160 * 144]u32 = [_]u32{0} ** (160 * 144),
    frame_ready: bool = false,
};

pub const Dma = struct {
    rVDMA_SRC_HIGH: u8 = 0, // HDMA1 etc
    rVDMA_SRC_LOW: u8 = 0,
    rVDMA_DEST_HIGH: u8 = 0,
    rVDMA_DEST_LOW: u8 = 0,
    rVDMA_LEN: u8 = 0,

    is_active: bool = false,
    src: u16 = 0,
    dest: u16 = 0,
    remaining: u16 = 0, // in blocks of 16 bytes
    block_active: bool = false,
    block_step: u16 = 0,
};

// PPU Registers
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
    ppu_mode: enum(u2) { hblank = 0, vblank = 1, oam_scan = 2, pixel_transfer = 3 } = .hblank,
    lyc_equals_ly: bool = false,
    hblank_intr_selected: bool = false,
    vblank_intr_selected: bool = false,
    oam_scan_intr_selected: bool = false,
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
    flags: ObjectFlags = .{},
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
    id_0: DmgColour = .white,
    id_1: DmgColour = .white,
    id_2: DmgColour = .white,
    id_3: DmgColour = .white,
};

pub const DmgObjectPaletteData = packed struct(u8) {
    id_0: DmgColour = 0,
    id_1: DmgColour = .white,
    id_2: DmgColour = .white,
    id_3: DmgColour = .white,
};

const DmgColour = enum(u2) { white, light_gray, dark_gray, black };

pub const CgbPaletteIndex = packed struct(u8) {
    palette_address: u6 = 0,
    _unused: u1 = 0,
    auto_increment: bool = false,
};

pub const CgbPaletteData = packed struct(u16) {
    red_intensity: u5 = 0,
    green_intensity: u5 = 0,
    blue_intensity: u5 = 0,
    _unused: u1 = 0,
};
