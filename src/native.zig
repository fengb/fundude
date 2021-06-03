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

const CYCLES_PER_MS = Fundude.MHz / 1000;
export fn fd_step_ms(fd: *Fundude, ms: i64) i32 {
    const cycles = ms * CYCLES_PER_MS;
    std.debug.assert(cycles < std.math.maxInt(i32));
    return fd_step_cycles(fd, @truncate(i32, cycles));
}

export fn fd_step_cycles(fd: *Fundude, cycles: i32) i32 {
    const target_cycles: i32 = cycles;
    var track = target_cycles;

    while (track >= 0) {
        const catchup = track > 140_000;
        fd.tick(catchup);
        track -= 4;

        if (fd.breakpoint == fd.cpu.reg._16.get(.PC)) {
            return target_cycles - track;
        }
    }

    return target_cycles - track;
}

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var window = c.SDL_CreateWindow("fundude", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 160, 144, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(
        window,
        0,
        c.SDL_RENDERER_PRESENTVSYNC,
    );
    defer c.SDL_DestroyRenderer(renderer);

    var fd: Fundude = .{};

    const data = try std.fs.cwd().readFileAlloc(allocator, "mario.gb", 0xfffffff);

    try fd.init(allocator, .{ .cart = data });

    var texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_ARGB1555,
        c.SDL_TEXTUREACCESS_STREAMING,
        160,
        144,
    );

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
                    const keys: input = .{
                        .up = sdl_event.key.keysym.sym == c.SDLK_LEFT,
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
                    } else {
                        _ = fd.inputs.release(&fd.mmu, .{ .raw = @bitCast(u8, keys) });
                    }
                },
                else => {},
            }
        }

        const ts = std.time.milliTimestamp();
        const elapsed = ts - prevSpin;
        _ = fd_step_ms(&fd, elapsed);
        prevSpin = ts;

        const screen = fd.video.screen().toArraySlice().ptr;
        var pixels: ?*c_void = undefined;
        var pitch: c_int = undefined;
        _ = c.SDL_LockTexture(texture, null, &pixels, &pitch);
        @memcpy(@ptrCast([*]u8, pixels.?), @ptrCast([*]u8, screen), 160 * 144 * 2);
        //@memset(@ptrCast([*]u8, pixels.?), 0xff, 144 * 160);
        c.SDL_UnlockTexture(texture);

        _ = c.SDL_RenderCopy(renderer, texture, null, null);
        c.SDL_RenderPresent(renderer);
    }
}
