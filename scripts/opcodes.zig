const std = @import("std");
const fundude = @import("fundude");

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();
    try stdout.print("<html>\n", .{});
    try stdout.print("<style>td {{ white-space: nowrap; font-family: monospace }}</style>\n", .{});
    try stdout.print("<html>\n<body>\n<table>\n", .{});

    try stdout.print("<tr>\n<th></th>\n", .{});
    for ([_]u8{0} ** 16) |_, i| {
        try stdout.print("<th>x{X}</th>\n", .{i});
    }
    try stdout.print("</tr>\n", .{});

    for ([_]u8{0} ** 16) |_, high| {
        try stdout.print("<tr><th>{X}x</th>\n", .{high});

        for ([_]u8{0} ** 16) |_, low| {
            const opcode = @intCast(u8, high << 4 | low);
            const op = fundude.Cpu.opDecode([3]u8{ opcode, 0xCD, 0xAB });

            var buffer: [16]u8 = undefined;
            try stdout.print("<td>{} <br />", .{op.disassemble(&buffer)});
            try stdout.print("{} ", .{op.length});
            if (op.durations[0] == op.durations[1]) {
                try stdout.print("{}\n", .{op.durations[0]});
            } else {
                try stdout.print("{}/{}\n", .{ op.durations[0], op.durations[1] });
            }
            try stdout.print("</td>\n", .{});
        }

        try stdout.print("</tr>\n", .{});
    }
    try stdout.print("</table>\n</body>\n</html>\n", .{});
}
