const std = @import("std");
const Console = @import("../gameboy/console.zig").Console;
const Joypad = @import("../gameboy/joypad.zig").Joypad;
const SDL = @cImport({
    @cInclude("SDL3/SDL.h");
});

const SCALE = 4;
const WIDTH = 160;
const HEIGHT = 144;
var turbo: bool = false;

pub const Window = struct {
    window: *SDL.SDL_Window,
    renderer: *SDL.SDL_Renderer,
    texture: *SDL.SDL_Texture,
    audio_stream: *SDL.SDL_AudioStream,
    file_rom_path: [std.fs.max_path_bytes]u8 = undefined,
    file_rom_path_len: usize = 0,
    file_dialog_cancelled: bool = false,

    pub fn init() Window {
        if (!SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_AUDIO)) sdlPanic();

        const window = SDL.SDL_CreateWindow(
            "Game Boy",
            WIDTH * SCALE,
            HEIGHT * SCALE,
            0,
        ) orelse sdlPanic();

        const renderer = SDL.SDL_CreateRenderer(window, null) orelse sdlPanic();

        const texture = SDL.SDL_CreateTexture(
            renderer,
            SDL.SDL_PIXELFORMAT_ARGB8888,
            SDL.SDL_TEXTUREACCESS_STREAMING,
            WIDTH,
            HEIGHT,
        ) orelse sdlPanic();

        const src_spec = SDL.SDL_AudioSpec{
            .format = SDL.SDL_AUDIO_F32,
            .channels = 2,
            .freq = 48000,
        };
        const audio_stream = SDL.SDL_OpenAudioDeviceStream(
            SDL.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
            &src_spec,
            audioCallback,
            null, // userdata set later
        ) orelse sdlPanic();

        return Window{
            .window = window,
            .renderer = renderer,
            .texture = texture,
            .audio_stream = audio_stream,
        };
    }

    pub fn deinit(self: *Window) void {
        SDL.SDL_DestroyTexture(self.texture);
        SDL.SDL_DestroyRenderer(self.renderer);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    pub fn run(self: *Window, gb: *Console) !void {
        _ = SDL.SDL_SetAudioStreamGetCallback(self.audio_stream, audioCallback, gb);
        _ = SDL.SDL_ResumeAudioStreamDevice(self.audio_stream);

        mainLoop: while (true) {
            var ev: SDL.SDL_Event = undefined;
            while (SDL.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    SDL.SDL_EVENT_QUIT => break :mainLoop,
                    SDL.SDL_EVENT_KEY_DOWN => {
                        if (ev.key.scancode == SDL.SDL_SCANCODE_S and !ev.key.repeat) {
                            turbo = !turbo;
                        } else if (!ev.key.repeat) {
                            setKey(gb.bus.joypad, ev.key.scancode, true);
                        }
                    },
                    SDL.SDL_EVENT_KEY_UP => {
                        setKey(gb.bus.joypad, ev.key.scancode, false);
                    },
                    else => {},
                }
            }

            if (gb.ppu.frame_ready.load(.acquire)) {
                gb.ppu.frame_ready.store(false, .release);
                _ = SDL.SDL_UpdateTexture(
                    self.texture,
                    null,
                    @ptrCast(&gb.ppu.display_buffer),
                    WIDTH * @sizeOf(u32),
                );
                _ = SDL.SDL_RenderClear(self.renderer);
                _ = SDL.SDL_RenderTexture(self.renderer, self.texture, null, null);
                _ = SDL.SDL_RenderPresent(self.renderer);
            }

            SDL.SDL_Delay(1);
        }
    }
    pub fn openFileDialog(self: *Window) ![]const u8 {
        var roms_buf: [std.fs.max_path_bytes]u8 = undefined;
        const roms_path = std.c.realpath("./roms", &roms_buf);

        SDL.SDL_ShowOpenFileDialog(
            fileDialogCallback,
            self,
            self.window,
            null,
            0,
            roms_path,
            false,
        );
        var ev: SDL.SDL_Event = undefined;
        while (self.file_rom_path_len == 0 and !self.file_dialog_cancelled) {
            _ = SDL.SDL_WaitEventTimeout(&ev, 10);
        }

        if (self.file_dialog_cancelled) return error.Cancelled;

        return self.file_rom_path[0..self.file_rom_path_len];
    }

    fn sdlPanic() noreturn {
        const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
        @panic(std.mem.sliceTo(str, 0));
    }

    fn setKey(jp: *Joypad, sc: SDL.SDL_Scancode, pressed: bool) void {
        const value: u8 = if (pressed) 0 else 1;

        switch (sc) {
            // D-pad
            SDL.SDL_SCANCODE_RIGHT => setBit(&jp.dpad, 0, value),
            SDL.SDL_SCANCODE_LEFT => setBit(&jp.dpad, 1, value),
            SDL.SDL_SCANCODE_UP => setBit(&jp.dpad, 2, value),
            SDL.SDL_SCANCODE_DOWN => setBit(&jp.dpad, 3, value),

            // Buttons
            SDL.SDL_SCANCODE_Z => setBit(&jp.buttons, 0, value), // A
            SDL.SDL_SCANCODE_X => setBit(&jp.buttons, 1, value), // B
            SDL.SDL_SCANCODE_RSHIFT => setBit(&jp.buttons, 2, value), // Select
            SDL.SDL_SCANCODE_RETURN => setBit(&jp.buttons, 3, value), // Start

            else => {},
        }
    }

    fn setBit(byte: *u8, bit: u3, value: u8) void {
        if (value == 0) {
            byte.* &= ~(@as(u8, 1) << bit); // pressed
        } else {
            byte.* |= (@as(u8, 1) << bit); // released
        }
    }

    fn fileDialogCallback(
        userdata: ?*anyopaque,
        filelist: [*c]const [*c]const u8,
        filter: c_int,
    ) callconv(.c) void {
        _ = filter;
        const self: *Window = @ptrCast(@alignCast(userdata));

        if (filelist == null or filelist[0] == null) {
            std.debug.print("Error or cancelled\n", .{});
            self.file_dialog_cancelled = true;
            return;
        }

        const path = std.mem.span(filelist[0]);
        @memcpy(self.file_rom_path[0..path.len], path);
        self.file_rom_path_len = path.len;
        self.file_rom_path[path.len] = 0;
    }
};

fn audioCallback(
    userdata: ?*anyopaque,
    stream: ?*SDL.SDL_AudioStream,
    additional_amount: c_int,
    _: c_int,
) callconv(.c) void {
    const gb: *Console = @ptrCast(@alignCast(userdata orelse return));
    if (additional_amount <= 0) return;

    const bytes: usize = @intCast(additional_amount);
    const samples_needed = bytes / (@sizeOf(f32) * 2);
    var buf: [4096]f32 = undefined;
    const count = @min(samples_needed, buf.len / 2);

    for (0..count) |i| {
        gb.stepToSample();
        buf[i * 2] = gb.apu.left_sample;
        buf[i * 2 + 1] = gb.apu.right_sample;
    }

    const byte_count: c_int = @intCast(count);
    _ = SDL.SDL_PutAudioStreamData(
        stream,
        &buf,
        byte_count * 8, // 2 channels * 4 bytes per f32
    );
}
