const Cartridge = @import("./cartridge/cartridge.zig").Cartridge;
const Console = @import("./gameboy/console.zig").Console;
const Cpu = @import("./gameboy/cpu/cpu.zig").Cpu;
const Bus = @import("./gameboy/bus.zig").Bus;
const Ppu = @import("./gameboy/ppu.zig").Ppu;
const Apu = @import("./gameboy/apu/apu.zig").Apu;
const Channel1 = @import("./gameboy/apu/channel_1.zig").Channel1;
const Channel2 = @import("./gameboy/apu/channel_2.zig").Channel2;
const Channel3 = @import("./gameboy/apu/channel_3.zig").Channel3;
const Channel4 = @import("./gameboy/apu/channel_4.zig").Channel4;
const Timer = @import("./gameboy/timer.zig").Timer;
const Joypad = @import("./gameboy/joypad.zig").Joypad;
const Window = @import("./gui/window.zig").Window;
const InterruptController = @import("./gameboy/interrupt_controller.zig").InterruptController;
const std = @import("std");
const SDL = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub fn main(init: std.process.Init) !void {
    var window: Window = .init();
    // Initialise allocator + io
    const allocator: std.mem.Allocator = init.gpa;
    const io: std.Io = init.io;

    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    // const stdout = &stdout_writer.interface;

    const path: []const u8 = try window.openFileDialog();
    std.debug.print("path: {s}\n", .{path});

    // Allocate buffer to store ROM
    const buffer = try allocator.alloc(u8, 4 * 1024 * 1024);
    defer allocator.free(buffer);

    // Load ROM into buffer
    const rom_buffer = try loadFile(allocator, io, path, buffer, false);
    defer allocator.free(rom_buffer);

    // Convert ROM path to save path
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const rom_name = std.fs.path.basename(path);
    const save_path: []const u8 = try std.fmt.bufPrint(&buf, "saves/{s}", .{rom_name});
    std.debug.print("save path: {s}\n", .{save_path});
    @memset(buffer, 0);

    // Load Save File into buffer
    const save_file_buffer = loadFile(allocator, io, save_path, buffer, true) catch null;
    defer if (save_file_buffer) |s| allocator.free(s);

    // Initialise Cartridge
    var cart = try Cartridge.init(allocator, rom_buffer);
    const cgb: bool = cart.cgb;

    // Load the save data if it exists
    if (save_file_buffer) |s| cart.load(s);

    defer cart.deinit();

    var interrupt_controller = InterruptController.init();
    var timer = Timer.init(&interrupt_controller);
    var ppu = Ppu.init(&interrupt_controller, cgb);
    var joypad = Joypad.init();

    var channel_1: Channel1 = .{};
    var channel_2: Channel2 = .{};
    var channel_3: Channel3 = .{};
    var channel_4: Channel4 = .{};
    var apu = Apu.init(&channel_1, &channel_2, &channel_3, &channel_4);
    const audio_stream_buffer = try allocator.alloc(f32, 1024);
    defer allocator.free(audio_stream_buffer);

    var bus = Bus.init(&cart, &timer, &interrupt_controller, &ppu, &apu, &joypad, cgb);
    var cpu = Cpu.init(&bus, &timer, &interrupt_controller, &ppu, &apu, cgb);
    bus.cpu = &cpu;

    // Initialise console
    var gb = Console.init(&interrupt_controller, &timer, &bus, &cpu, &ppu, &apu);

    try window.run(&gb);

    try writeSaveData(io, save_path, cart.save());
    std.debug.print("Game Saved\n", .{});
}

fn loadFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    buffer: []u8,
    isRelative: bool,
) ![:0]u8 {
    // Open file based on CWD and provided relative path
    const cwd = std.Io.Dir.cwd();
    const file = if (isRelative)
        try cwd.openFile(io, path, .{ .mode = .read_only })
    else
        try std.Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_only });
    defer file.close(io);

    var reader = file.reader(io, buffer);

    // Read the file contents into the buffer
    return try std.zig.readSourceFileToEndAlloc(allocator, &reader);
}

fn writeSaveData(
    io: std.Io,
    path: []const u8,
    data: []const u8,
) !void {
    const cwd: std.Io.Dir = std.Io.Dir.cwd();
    const file: std.Io.File = try cwd.createFile(io, path, .{ .read = true });
    defer file.close(io);

    try file.writeStreamingAll(io, data);
}
