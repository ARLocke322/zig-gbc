// create, engine owns the memory, platform provides rom and save bytes, engine gives back pointer to the gb, memory freed once engine shuts down

export fn gb_create(
  rom_ptr: [*]const u8,
  rom_len: usize,
  save_ptr: ?[*]const u8,
  save_len: usize,
) ?*Emulator

// shut down, tells engine to free all memory

export fn gb_shutdown(
  emu: *Emulator
) void

// get save data, engine returns a pointer to the save data and its length, platform copies it to disk

const GbSaveData = extern struct {
    data: ?[*]const u8,
    length: usize,
};

export fn gb_get_save_data(
  emu: *Emulator,
) GbSaveData

// send button, platform sends the list of current buttons pressed to the engine, engine updates its registers

const GbButtons = extern struct {
  a: bool,
  b: bool,
  etc...
};

export fn gb_send_inputs(
  emu: *Emulator,
  buttons: GbButtons,
) void

// samples, platform sends pointer to buffer and number or samples needed, engine writes requested number of samples into it

export fn gb_sample_audio(
  emu: *Emulator,
  sample_buffer: [*]f32,
  frame_count: usize,
) void

// screen, platform gets pointer to screen buffer from engine and whether its ready, if ready it copies it to the screen

const GbScreenData = extern struct {
  data: *const [160 * 144]u32,
  frame_ready: bool,
};

export fn gb_get_screen_data(
  emu: *Emulator,
) GbScreenData


