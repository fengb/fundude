const std = @import("std");
const Fundude = @import("fundude");

pub fn main() !u8 {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len != 2) {
        std.debug.print("Usage: {s} [path/to/test-rom.gb]\n", .{"turbo"});
        return 1;
    }

    const cwd = std.fs.cwd();
    const file = try cwd.openFile(args[1], .{});
    defer file.close();

    const size = try file.getEndPos();
    const cart = try std.heap.page_allocator.alloc(u8, size);
    defer std.heap.page_allocator.free(cart);

    const red = try file.readAll(cart);
    if (red != cart.len) {
        std.debug.print("Cart length {} != {}", .{ red, cart.len });
        return 1;
    }

    var fd = try std.heap.page_allocator.create(Fundude);
    defer std.heap.page_allocator.destroy(fd);
    const ticks = Fundude.MHz / 4 * 500;
    {
        try fd.load(cart);
        var timer = try std.time.Timer.start();
        var i: usize = 0;
        while (i < ticks) : (i += 1) {
            _ = fd.tick(true);
        }
        std.debug.print("Catchup: {}\n", .{std.fmt.fmtDuration(timer.read())});
    }
    {
        try fd.load(cart);
        var timer = try std.time.Timer.start();
        var i: usize = 0;
        while (i < ticks) : (i += 1) {
            _ = fd.tick(false);
        }
        std.debug.print("Slowpath: {}\n", .{std.fmt.fmtDuration(timer.read())});
    }

    return 0;
}
