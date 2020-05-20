const std = @import("std");
const Fundude = @import("fundude");

pub fn main() !u8 {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len != 2) {
        std.debug.warn("Usage: {} [path/to/test-rom.gb]\n", .{"testrom"});
        return 1;
    }

    var cart: [0x8000]u8 = undefined;

    const cwd = std.fs.cwd();
    const file = try cwd.openFile(args[1], .{});
    defer file.close();

    const red = try file.readAll(&cart);
    if (red != cart.len) {
        std.debug.warn("Cart length {} != {}", .{ red, cart.len });
        return 1;
    }

    var fd: Fundude = undefined;
    try fd.load(&cart);
    while (fd.cpu.reg._16.get(.PC) < 0x7FFD) {
        _ = fd.step();
    }

    const stack_top = fd.cpu.reg._16.get(.SP);
    const expecteds = cart[0x4000..];
    const actuals = std.mem.asBytes(&fd.mmu.dyn)[stack_top..0xE000];

    std.debug.warn("Result length: 0x{X}\n", .{actuals.len});

    var result: u8 = 0;
    for (actuals) |actual, i| {
        if (actual != expecteds[i]) {
            std.debug.warn("0x{X}: 0x{X} != 0x{X} \n", .{ stack_top + i, actual, expecteds[i] });
        }
    }

    return result;
}
