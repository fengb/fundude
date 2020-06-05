const std = @import("std");

const Fundude = @import("main.zig");

fn Serializer(comptime T: type, comptime field_names: []const []const u8) type {
    return struct {
        pub const ssize: comptime_int = blk: {
            var result = 0;
            inline for (field_names) |field_name| {
                var fake: T = undefined;
                const FieldType = @TypeOf(@field(fake, field_name));
                result += @sizeOf(u32) + @sizeOf(FieldType);
            }
            break :blk result;
        };

        fn dump(self: T, out_stream: var) !void {
            inline for (field_names) |field_name| {
                const field_ptr = &@field(self, field_name);
                const FieldType = @TypeOf(field_ptr.*);
                try out_stream.writeIntNative(u32, @sizeOf(FieldType));
                try out_stream.writeAll(std.mem.asBytes(field_ptr));
            }
        }

        fn validate(in_stream: var) !void {
            var fake: T = undefined;
            inline for (field_names) |field_name| {
                const FieldType = @TypeOf(@field(fake, field_name));
                const wire_size = @sizeOf(FieldType);
                if (wire_size != try in_stream.readIntNative(u32)) {
                    return error.SizeMismatch;
                }

                try in_stream.skipBytes(wire_size);
            }
        }

        fn restore(self: *T, in_stream: var) !void {
            inline for (field_names) |field_name| {
                const FieldType = @TypeOf(@field(self, field_name));
                const wire_size = @sizeOf(FieldType);
                if (wire_size != try in_stream.readIntNative(u32)) {
                    return error.SizeMismatch;
                }

                switch (@typeInfo(FieldType)) {
                    .Bool => @field(self, field_name) = 0 != try in_stream.readByte(),
                    .Int => |int_info| {
                        const WireType = std.meta.Int(false, 8 * wire_size);
                        const raw = try in_stream.readIntNative(WireType);
                        @field(self, field_name) = @intCast(FieldType, raw);
                    },
                    else => {
                        const result_location = &@field(self, field_name);
                        try in_stream.readNoEof(std.mem.asBytes(result_location));
                    },
                }
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

pub const size = magic_number.len + cart_meta_len +
    Cpu.ssize + Mmu.ssize + Video.ssize + Timer.ssize;

const magic_number = [_]u8{ 0xDC, 0x00, 0x46, 0x44, 0x0D, 0x0A, 0x1A, 0x0A };
const cart_meta_len = 0x18;

pub fn dump(fd: Fundude, out_stream: var) !void {
    try out_stream.writeAll(&magic_number);
    try out_stream.writeAll(fd.mmu.cart[0x134..][0..cart_meta_len]);

    try Cpu.dump(fd.cpu, out_stream);
    try Mmu.dump(fd.mmu, out_stream);
    try Timer.dump(fd.timer, out_stream);

    try Video.dump(fd.video, out_stream);
}

fn validateHeader(fd: *Fundude, in_stream: var) !void {
    const header = try in_stream.readBytesNoEof(magic_number.len);
    if (!std.mem.eql(u8, &header, &magic_number)) {
        return error.HeaderMismatch;
    }
    const cart_meta = try in_stream.readBytesNoEof(0x18);
    if (!std.mem.eql(u8, &cart_meta, fd.mmu.cart[0x134..][0..cart_meta_len])) {
        return error.CartMismatch;
    }
}

pub fn validate(fd: *Fundude, in_stream: var) !void {
    try validateHeader(fd, in_stream);

    try Cpu.validate(in_stream);
    try Mmu.validate(in_stream);
    try Timer.validate(in_stream);

    try Video.validate(in_stream);
}

pub fn restore(fd: *Fundude, in_stream: var) !void {
    try validateHeader(fd, in_stream);

    try Cpu.restore(&fd.cpu, in_stream);
    try Mmu.restore(&fd.mmu, in_stream);
    try Timer.restore(&fd.timer, in_stream);

    try Video.restore(&fd.video, in_stream);
    fd.video.resetCache();
}
