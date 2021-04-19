const std = @import("std");
const Fundude = @import("fundude");

pub fn main() !u8 {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        std.debug.print("Usage: {s} [path/to/test-rom.gb]\n", .{"testrom"});
        return 1;
    }

    var status: u8 = 0;
    for (args[1..]) |arg| {
        var cart: [0x8000]u8 = undefined;

        const cwd = std.fs.cwd();
        const file = try cwd.openFile(arg, .{});
        defer file.close();

        const red = try file.readAll(&cart);
        if (red != cart.len) {
            std.debug.print("Cart length {} != {}", .{ red, cart.len });
            return 1;
        }

        const fd = try std.heap.page_allocator.create(Fundude);
        defer std.heap.page_allocator.destroy(fd);

        try fd.load(&cart);
        fd.mmu.loadBootloader(Fundude.Mmu.Bootloaders.mini);
        while (fd.cpu.reg._16.get(.PC) < 0x7FFD) {
            _ = fd.tick(false);
        }

        const stack_top = fd.cpu.reg._16.get(.SP);
        const expecteds = cart[0x4000..];
        const actuals = std.mem.asBytes(&fd.mmu.dyn)[stack_top..0xE000];

        std.debug.print("\n{s}\n    compared bytes: 0x{X}\n", .{ arg, actuals.len });

        for (actuals) |actual, i| {
            if (actual != expecteds[i]) {
                std.debug.print("    0x{X}: 0x{X} != 0x{X} \n", .{ stack_top + i, actual, expecteds[i] });
                status = 1;
            }
        }
    }

    return status;
}
