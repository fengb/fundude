const std = @import("std");

const Fundude = @import("main.zig");

fn Serializer(comptime T: type, comptime field_names: []const []const u8) type {
    return struct {
        fn dump(self: T, out_stream: var) !void {
            inline for (field_names) |field_name| {
                const field_value = @field(self, field_name);
                const FieldType = @TypeOf(field_value);
                try out_stream.writeIntNative(u32, @sizeOf(FieldType));
                try out_stream.writeAll(std.mem.asBytes(&field_value));
            }
        }

        fn restore(self: *T, in_stream: var) !void {
            inline for (field_names) |field_name| {
                const FieldType = @TypeOf(@field(self, field_name));
                const check_size = try in_stream.readIntNative(u32);
                if (check_size != @sizeOf(FieldType)) {
                    return error.SizeMismatch;
                }
                @field(self, field_name) = @bitCast(FieldType, try in_stream.readBytesNoEof(@sizeOf(FieldType)));
            }
        }
    };
}

const Foo = struct {
    bar: u8,
    baz: u16,

    const S = Serializer(@This(), &[_][]const u8{ "bar", "baz" });
};

test "dump" {
    const foo = Foo{ .bar = 0x12, .baz = 0x3456 };
    var buf: [0x1000]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);

    try Foo.S.dump(foo, stream.outStream());

    // Size (bar = u8)
    std.testing.expectEqual(@as(u8, 1), buf[0]);
    std.testing.expectEqual(@as(u8, 0), buf[1]);
    std.testing.expectEqual(@as(u8, 0), buf[2]);
    std.testing.expectEqual(@as(u8, 0), buf[3]);

    // Payload (bar = 0x12)
    std.testing.expectEqual(@as(u8, 0x12), buf[4]);

    // Size (baz = u16)
    std.testing.expectEqual(@as(u8, 2), buf[5]);
    std.testing.expectEqual(@as(u8, 0), buf[6]);
    std.testing.expectEqual(@as(u8, 0), buf[7]);
    std.testing.expectEqual(@as(u8, 0), buf[8]);

    // Payload (bar = 0x3456)
    std.testing.expectEqual(@as(u8, 0x56), buf[9]);
    std.testing.expectEqual(@as(u8, 0x34), buf[10]);
}

test "restore" {
    const buf = [_]u8{ 1, 0, 0, 0, 0x12, 2, 0, 0, 0, 0x56, 0x34 };

    var stream = std.io.fixedBufferStream(&buf);
    var foo: Foo = undefined;

    try Foo.S.restore(&foo, stream.inStream());
    std.testing.expectEqual(@as(u8, 0x12), foo.bar);
    std.testing.expectEqual(@as(u16, 0x3456), foo.baz);
}

const Cpu = Serializer(Fundude.Cpu, &[_][]const u8{
    "mode",
    "interrupt_master",
    "reg",
});
const Mmu = Serializer(Fundude.Mmu, &[_][]const u8{
    "dyn",
    "bank",
});
const Video = Serializer(Fundude.Video, &[_][]const u8{
    "buffers",
    "screen_index",
    "clock",
});
const Timer = Serializer(Fundude.Timer, &[_][]const u8{
    "clock",
    "timer",
});

pub fn dump(fd: Fundude, out_stream: var) !void {
    try Cpu.dump(fd.cpu, out_stream);
    try Mmu.dump(fd.mmu, out_stream);
    try Video.dump(fd.video, out_stream);
    try Timer.dump(fd.timer, out_stream);
}

pub fn restore(fd: *Fundude, in_stream: var) !void {
    try Cpu.restore(&fd.cpu, in_stream);
    try Mmu.restore(&fd.mmu, in_stream);
    try Video.restore(&fd.video, in_stream);
    try Timer.restore(&fd.timer, in_stream);
}
