const std = @import("std");
const assert = std.debug.assert;
const InterruptController = @import("interrupt_controller.zig").InterruptController;
const Cpu = @import("./cpu/cpu.zig").Cpu;
const Bus = @import("bus.zig").Bus;
const renderScanlineDmg = @import("render_dmg.zig").renderScanlineDmg;
const renderScanlineCgb = @import("render_cgb.zig").renderScanlineCgb;

pub const Ppu = struct {
    tile_data: [0x1800 * 2]u8, // 0x1800 * 2 banks
    tile_map_1: [0x400 * 2]u8, // 0x400 * 2 banks
    tile_map_2: [0x400 * 2]u8, // 0x400 * 2 banks
    oam: [0xA0]u8, // FE00 - FE9F (fixed size)
    lcd_control: u8, // FF40
    stat: u8, // FF41
    scy: u8, // FF42
    scx: u8, // FF43
    ly: u8, // FF44
    lyc: u8, // FF45
    dma: u8, // FF46
    bgp: u8, // FF47
    obp0: u8, // FF48
    obp1: u8, // FF49
    wy: u8, // FF4A
    wx: u8, // FF4B
    bcps: u8,
    bcpd: u8,
    ocps: u8,
    ocpd: u8,
    opri: u8,
    window_line: u8,
    cycles: u16,
    interrupt_controller: *InterruptController,
    display_buffer: [160 * 144]u32,
    // Internal latched values
    latched_scx: u8 = 0,
    latched_scy: u8 = 0,
    latched_bgp: u8 = 0,
    latched_obp0: u8 = 0,
    latched_obp1: u8 = 0,
    latched_lcd_control: u8 = 0,
    latched_wy: u8 = 0,
    latched_wx: u8 = 0,
    current_signal: bool = false,
    stat_int_signal: bool = false,

    rVDMA_SRC_HIGH: u8 = 0, // HDMA1 etc
    rVDMA_SRC_LOW: u8 = 0,
    rVDMA_DEST_HIGH: u8 = 0,
    rVDMA_DEST_LOW: u8 = 0,
    rVDMA_LEN: u8 = 0,

    hdma_active: bool = false,
    hdma_src: u16 = 0,
    hdma_dest: u16 = 0,
    hdma_remaining: u16 = 0, // in blocks of 16 bytes
    //
    cgb: bool = false,
    vram_bank: u1 = 0,
    bg_cram: [64]u8,
    obj_cram: [64]u8,
    //
    bg_idx: [160]u2,
    bg_palettes: [8][4]u32 = undefined,
    obj_palettes: [8][4]u32 = undefined,

    frame_ready: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn init(interrupt_controller: *InterruptController, cgb: bool) Ppu {
        return Ppu{
            .tile_data = [_]u8{0} ** 0x3000,
            .tile_map_1 = [_]u8{0} ** 0x800,
            .tile_map_2 = [_]u8{0} ** 0x800,
            .oam = [_]u8{0} ** 0xA0,
            .lcd_control = 0x91,
            .stat = 0x85,
            .scy = 0,
            .scx = 0,
            .ly = 0,
            .lyc = 0,
            .dma = 0,
            .bgp = 0xFC,
            .obp0 = 0,
            .obp1 = 0,
            .wy = 0,
            .wx = 0,
            .bcps = 0,
            .bcpd = 0,
            .ocps = 0,
            .opri = 0,
            .ocpd = 0,
            .window_line = 0,
            .cycles = 0,
            .interrupt_controller = interrupt_controller,
            .display_buffer = [_]u32{0} ** (160 * 144),
            .cgb = cgb,
            .bg_cram = [_]u8{0} ** 0x40,
            .obj_cram = [_]u8{0} ** 0x40,
            .bg_idx = [_]u2{0} ** 160,
        };
    }

    pub fn read8(self: *Ppu, addr: u16) u8 {
        assert((addr >= 0x8000 and addr <= 0x9FFF) or
            (addr >= 0xFE00 and addr <= 0xFF4F) or
            (addr >= 0xFF68 and addr <= 0xFF6C));
        // const current_mode = self.get_ppu_mode();
        // if (addr >= 0x8000 and addr <= 0x9FFF and current_mode == 3) return 0xFF;
        // if (addr >= 0xFE00 and addr <= 0xFE9F and (current_mode == 2 or current_mode == 3)) return 0xFF;
        return switch (addr) {
            0x8000...0x97FF => {
                if (self.vram_bank == 0) {
                    return self.tile_data[addr - 0x8000];
                } else {
                    return self.tile_data[addr - 0x8000 + 0x1800];
                }
            },
            0x9800...0x9BFF => {
                if (self.vram_bank == 0) {
                    return self.tile_map_1[addr - 0x9800];
                } else {
                    return self.tile_map_1[addr - 0x9800 + 0x400];
                }
            },
            0x9C00...0x9FFF => {
                if (self.vram_bank == 0) {
                    return self.tile_map_2[addr - 0x9C00];
                } else {
                    return self.tile_map_2[addr - 0x9C00 + 0x400];
                }
            },
            0xFE00...0xFE9F => self.oam[addr - 0xFE00],
            0xFF40 => self.lcd_control,
            0xFF41 => self.stat,
            0xFF42 => self.scy,
            0xFF43 => self.scx,
            0xFF44 => self.ly,
            0xFF45 => self.lyc,
            0xFF46 => self.dma,
            0xFF47 => self.bgp,
            0xFF48 => self.obp0,
            0xFF49 => self.obp1,
            0xFF4A => self.wy,
            0xFF4B => self.wx,
            0xFF4F => 0xFF & @as(u8, self.vram_bank),
            0xFF68 => self.bcps,
            0xFF69 => self.getBcpd(),
            0xFF6A => self.ocps,
            0xFF6B => self.getOcpd(),
            0xFF6C => self.opri,
            else => unreachable,
        };
    }

    pub fn write8(
        self: *Ppu,
        addr: u16,
        val: u8,
    ) void {
        assert((addr >= 0x8000 and addr <= 0x9FFF) or
            (addr >= 0xFE00 and addr <= 0xFF4F) or
            (addr >= 0xFF68 and addr <= 0xFF6C));
        // const current_mode = self.get_ppu_mode();
        // if (addr >= 0x8000 and addr <= 0x9FFF and current_mode == 3) return;
        // if (addr >= 0xFE00 and addr <= 0xFE9F and (current_mode == 2 or current_mode == 3)) return;
        switch (addr) {
            0x8000...0x97FF => {
                if (self.vram_bank == 0) {
                    self.tile_data[addr - 0x8000] = val;
                } else {
                    self.tile_data[addr - 0x8000 + 0x1800] = val;
                }
            },
            0x9800...0x9BFF => {
                if (self.vram_bank == 0) {
                    self.tile_map_1[addr - 0x9800] = val;
                } else {
                    self.tile_map_1[addr - 0x9800 + 0x400] = val;
                }
            },
            0x9C00...0x9FFF => {
                if (self.vram_bank == 0) {
                    self.tile_map_2[addr - 0x9C00] = val;
                } else {
                    self.tile_map_2[addr - 0x9C00 + 0x400] = val;
                }
            },
            0xFE00...0xFE9F => self.oam[addr - 0xFE00] = val,
            0xFF40 => {
                self.lcd_control = val;
            },
            0xFF41 => {
                self.stat = (val & 0xF8) | (self.stat & 0x07);
                self.handle_stat_interrupt();
            },
            0xFF42 => self.scy = val,
            0xFF43 => self.scx = val,
            0xFF44 => {},
            0xFF45 => {
                self.lyc = val;
                self.handle_stat_interrupt();
            },
            0xFF46 => unreachable,
            0xFF47 => self.bgp = val,
            0xFF48 => self.obp0 = val,
            0xFF49 => self.obp1 = val,
            0xFF4A => self.wy = val,
            0xFF4B => self.wx = val,
            0xFF4F => self.vram_bank = @truncate(val),
            0xFF68 => self.bcps = val,
            0xFF69 => self.setBcpd(val),
            0xFF6A => self.ocps = val,
            0xFF6B => self.setOcpd(val),
            0xFF6C => self.opri = val,
            else => unreachable,
        }
    }

    fn getBcpd(self: *Ppu) u8 {
        const tgt_address: u6 = @truncate(self.bcps);
        const mode: u2 = @truncate(self.stat);
        if (mode != 3) return self.bg_cram[tgt_address];
        return 0xFF;
    }

    fn getOcpd(self: *Ppu) u8 {
        const tgt_address: u6 = @truncate(self.ocps);
        const mode: u2 = @truncate(self.stat);
        if (mode != 3) return self.obj_cram[tgt_address];
        return 0xFF;
    }

    fn setBcpd(self: *Ppu, val: u8) void {
        const tgt_address: u6 = @truncate(self.bcps);
        const auto_increment: bool = (self.bcps & 0x80) == 0x80;

        if (auto_increment) self.bcps =
            (self.bcps & 0x80) | ((tgt_address +% 1) & 0x3F);

        const mode: u2 = @truncate(self.stat);
        if (mode != 3) self.bg_cram[tgt_address] = val;
    }

    fn setOcpd(self: *Ppu, val: u8) void {
        const tgt_address: u6 = @truncate(self.ocps);
        const auto_increment: bool = (self.ocps & 0x80) == 0x80;

        if (auto_increment) self.ocps =
            (self.ocps & 0x80) | ((tgt_address +% 1) & 0x3F);

        const mode: u2 = @truncate(self.stat);
        if (mode != 3) self.obj_cram[tgt_address] = val;
    }

    pub fn tick(self: *Ppu, cpu: *Cpu, bus: *Bus, cycles: u16) void {
        if ((self.lcd_control & 0x80) == 0) {
            self.set_ppu_mode(2);
            self.ly = 0;
            self.cycles = 0;
            return;
        }

        self.cycles += cycles;
        const mode: u2 = @truncate(self.stat);
        switch (mode) {
            0x00 => self.handle_hblank(cpu, bus),
            0x01 => self.handle_vblank(),
            0x02 => self.handle_oam_scan(),
            0x03 => self.handle_render(),
        }
    }

    fn handle_hblank(self: *Ppu, cpu: *Cpu, bus: *Bus) void {
        if (self.cycles >= 204) {
            if (self.hdma_active and self.ly < 144) {
                self.execute_hdma_block(cpu, bus);
            }
            self.ly +%= 1;
            self.cycles -= 204;
            if (self.ly == 144) {
                self.set_ppu_mode(1);
                self.interrupt_controller.request(InterruptController.VBLANK);
                self.frame_ready.store(true, .release);
            } else self.set_ppu_mode(2);

            self.handle_stat_interrupt();
        }
    }

    fn execute_hdma_block(self: *Ppu, cpu: *Cpu, bus: *Bus) void {
        for (0..0x10) |i| {
            const byte = bus.read8(self.hdma_src + @as(u16, @intCast(i)));
            // self.write8(self.hdma_dest, byte);
            self.write8(self.hdma_dest + @as(u16, @intCast(i)), byte);
        }

        self.hdma_src += 0x10;
        self.hdma_dest += 0x10;
        self.hdma_remaining -= 1;
        cpu.stall_cycles += 32;

        if (self.hdma_remaining == 0) {
            self.hdma_active = false;
        }
    }

    fn handle_vblank(self: *Ppu) void {
        if (self.cycles >= 456) {
            self.ly +%= 1;
            self.cycles -= 456;
            if (self.ly > 153) {
                self.ly = 0;
                self.window_line = 0;
                self.set_ppu_mode(2);
            }

            self.handle_stat_interrupt();
        }
    }

    fn handle_oam_scan(self: *Ppu) void {
        if (self.cycles >= 80) {
            self.latched_scx = self.scx;
            self.latched_scy = self.scy;
            self.latched_bgp = self.bgp;
            self.latched_obp0 = self.obp0;
            self.latched_obp1 = self.obp1;
            self.latched_lcd_control = self.lcd_control;
            self.latched_wx = self.wx;
            self.latched_wy = self.wy;
            self.set_ppu_mode(3);
            self.cycles -= 80;

            self.handle_stat_interrupt();
        }
    }

    fn handle_render(self: *Ppu) void {
        if (self.cycles >= 172) {
            if (self.cgb)
                renderScanlineCgb(self)
            else
                renderScanlineDmg(self);

            self.set_ppu_mode(0);
            self.cycles -= 172;

            self.handle_stat_interrupt();
        }
    }

    fn handle_stat_interrupt(self: *Ppu) void {
        if (self.ly == self.lyc) {
            self.stat |= 0x04;
        } else {
            self.stat &= ~@as(u8, 0x04);
        }

        self.current_signal = false;

        const bit_6: bool = @as(u1, @truncate(self.stat >> 6)) == 1;
        const bit_5: bool = @as(u1, @truncate(self.stat >> 5)) == 1;
        const bit_4: bool = @as(u1, @truncate(self.stat >> 4)) == 1;
        const bit_3: bool = @as(u1, @truncate(self.stat >> 3)) == 1;
        const mode: u2 = @truncate(self.stat);

        if ((bit_6 and self.lyc == self.ly) or
            (bit_5 and mode == 2) or
            (bit_4 and mode == 1) or
            (bit_3 and mode == 0))
        {
            self.current_signal = true;
        }

        if (self.current_signal and !self.stat_int_signal) { // rising edge
            self.interrupt_controller.request(InterruptController.LCD_STAT);
        }

        self.stat_int_signal = self.current_signal;
    }

    fn set_ppu_mode(self: *Ppu, mode: u2) void {
        self.stat = (self.stat & 0xFC) | mode;
    }

    fn get_ppu_mode(self: *Ppu) u2 {
        return @truncate(self.stat);
    }
};
