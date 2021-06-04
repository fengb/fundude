const std = @import("std");
const Fundude = @import("main.zig");

const c = @cImport({
    @cInclude("SDL.h");
});

const input = packed struct {
    right: bool,
    left: bool,
    up: bool,
    down: bool,

    a: bool,
    b: bool,
    select: bool,
    start: bool,
};

pub fn main() anyerror!u8 {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var arg_iter = std.process.ArgIterator.init();

    const binary_name = try arg_iter.next(allocator) orelse @panic("missing first arugment");
    defer allocator.free(binary_name);

    const rom_file = try arg_iter.next(allocator) orelse {
        std.debug.print("usage:\n  {s} [rom.gb]\n", .{binary_name});
        return 1;
    };
    defer allocator.free(rom_file);

    var fd: Fundude = .{};

    const data = try std.fs.cwd().readFileAlloc(allocator, rom_file, 0xfffffff);
    defer allocator.free(data);

    try fd.init(allocator, .{ .cart = data });
    defer fd.deinit(allocator);

    const screen = fd.video.screen();

    var window = c.SDL_CreateWindow(
        "fundude",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        screen.width * 3,
        screen.height * 3,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE,
    );
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(
        window,
        0,
        c.SDL_RENDERER_PRESENTVSYNC,
    );
    defer c.SDL_DestroyRenderer(renderer);

    _ = c.SDL_RenderSetLogicalSize(renderer, screen.width, screen.height);

    var texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_ARGB1555,
        c.SDL_TEXTUREACCESS_STREAMING,
        screen.width,
        screen.height,
    );
    defer c.SDL_DestroyTexture(texture);

    _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);
    _ = c.SDL_RenderClear(renderer);

    var frame: usize = 0;
    var prevSpin: i64 = std.time.milliTimestamp();

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN, c.SDL_KEYUP => {

                    //TODO: configurable keymap
                    const keys: input = .{
                        .up = sdl_event.key.keysym.sym == c.SDLK_UP,
                        .down = sdl_event.key.keysym.sym == c.SDLK_DOWN,
                        .left = sdl_event.key.keysym.sym == c.SDLK_LEFT,
                        .right = sdl_event.key.keysym.sym == c.SDLK_RIGHT,

                        .a = sdl_event.key.keysym.sym == c.SDLK_PERIOD,
                        .b = sdl_event.key.keysym.sym == c.SDLK_COMMA,

                        .select = sdl_event.key.keysym.sym == c.SDLK_BACKSPACE,
                        .start = sdl_event.key.keysym.sym == c.SDLK_RETURN,
                    };

                    if (sdl_event.type == c.SDL_KEYDOWN) {
                        const changed = fd.inputs.press(&fd.mmu, .{ .raw = @bitCast(u8, keys) });
                        if (changed) {
                            fd.cpu.mode = .norm;
                            fd.mmu.dyn.io.IF.joypad = true;
                        }
                        if (sdl_event.key.keysym.sym == c.SDLK_a) {
                            fd.temportal.rewind(&fd);
                        }
                    } else {
                        _ = fd.inputs.release(&fd.mmu, .{ .raw = @bitCast(u8, keys) });
                    }
                },
                else => {},
            }
        }

        const ts = std.time.milliTimestamp();
        const elapsed = ts - prevSpin;
        _ = fd.step_ms(elapsed, false);
        prevSpin = ts;

        // draw the current framebuffer to the screen
        // TODO: find a more optimal way of doing this
        var pixels: ?*c_void = undefined;
        var pitch: c_int = undefined;
        _ = c.SDL_LockTexture(texture, null, &pixels, &pitch);
        @memcpy(
            @ptrCast([*]u8, pixels.?),
            @ptrCast([*]u8, screen.toArraySlice().ptr),
            screen.width * screen.height * 2,
        );
        c.SDL_UnlockTexture(texture);

        _ = c.SDL_RenderCopy(renderer, texture, null, null);
        c.SDL_RenderPresent(renderer);
    }

    return 0;
}
