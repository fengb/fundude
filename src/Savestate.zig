const std = @import("std");

const Fundude = @import("main.zig");

const Savestate = @This();

data: [size]u8,

pub fn dumpFrom(self: *Savestate, fd: Fundude) void {
    var stream = std.io.fixedBufferStream(&self.data);
    dump(fd, stream.writer()) catch unreachable;
}

pub fn restoreInto(self: Savestate, fd: *Fundude) !void {
    var stream = std.io.fixedBufferStream(&self.data);
    try restore(fd, stream.reader());
}

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

        fn dump(self: T, writer: anytype) !void {
            inline for (field_names) |field_name| {
                const field_ptr = &@field(self, field_name);
                const FieldType = @TypeOf(field_ptr.*);
                try writer.writeIntNative(u32, @sizeOf(FieldType));
                try writer.writeAll(std.mem.asBytes(field_ptr));
            }
        }

        fn validate(reader: anytype) !void {
            var fake: T = undefined;
            inline for (field_names) |field_name| {
                const FieldType = @TypeOf(@field(fake, field_name));
                const wire_size = @sizeOf(FieldType);
                if (wire_size != try reader.readIntNative(u32)) {
                    return error.SizeMismatch;
                }

                try reader.skipBytes(wire_size, .{ .buf_size = 64 });
            }
        }

        fn restore(self: *T, reader: anytype) !void {
            inline for (field_names) |field_name| {
                const FieldType = @TypeOf(@field(self, field_name));
                const wire_size = @sizeOf(FieldType);
                if (wire_size != try reader.readIntNative(u32)) {
                    return error.SizeMismatch;
                }

                switch (@typeInfo(FieldType)) {
                    .Bool => @field(self, field_name) = 0 != try reader.readByte(),
                    .Int => |int_info| {
                        const WireType = std.meta.Int(.unsigned, 8 * wire_size);
                        const raw = try reader.readIntNative(WireType);
                        @field(self, field_name) = @intCast(FieldType, raw);
                    },
                    else => {
                        const result_location = &@field(self, field_name);
                        try reader.readNoEof(std.mem.asBytes(result_location));
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

    try Foo.S.dump(foo, stream.writer());

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

    try Foo.S.restore(&foo, stream.reader());
    std.testing.expectEqual(@as(u8, 0x12), foo.bar);
    std.testing.expectEqual(@as(u16, 0x3456), foo.baz);
}

const Cpu = Serializer(Fundude.Cpu, &[_][]const u8{
    "mode",
    "interrupt_master",
    "reg",
    "duration",
    "remaining",
    "next",
});
const Mmu = Serializer(Fundude.Mmu, &[_][]const u8{
    "dyn",
    "bank",
});
const Video = Serializer(Fundude.Video, &[_][]const u8{
    "clock",
});
const Timer = Serializer(Fundude.Timer, &[_][]const u8{
    "clock",
    "timer",
});

pub const size = magic_number.len + cart_meta_len +
    Cpu.ssize + Mmu.ssize + Video.ssize + Timer.ssize;

const version = 0x00;
const magic_number = [_]u8{ 0xDC, version, 0x46, 0x44, 0x0D, 0x0A, 0x1A, 0x0A };
const cart_meta_len = 0x18;

pub fn dump(fd: Fundude, writer: anytype) !void {
    try writer.writeAll(&magic_number);
    try writer.writeAll(fd.mmu.cart[0x134..][0..cart_meta_len]);

    try Cpu.dump(fd.cpu, writer);
    try Mmu.dump(fd.mmu, writer);
    try Timer.dump(fd.timer, writer);

    try Video.dump(fd.video, writer);
}

fn validateHeader(fd: *Fundude, reader: anytype) !void {
    const header = try reader.readBytesNoEof(magic_number.len);
    if (!std.mem.eql(u8, &header, &magic_number)) {
        return error.HeaderMismatch;
    }
    const cart_meta = try reader.readBytesNoEof(0x18);
    if (!std.mem.eql(u8, &cart_meta, fd.mmu.cart[0x134..][0..cart_meta_len])) {
        return error.CartMismatch;
    }
}

pub fn validate(fd: *Fundude, reader: anytype) !void {
    try validateHeader(fd, reader);

    try Cpu.validate(reader);
    try Mmu.validate(reader);
    try Timer.validate(reader);

    try Video.validate(reader);
}

pub fn restore(fd: *Fundude, reader: anytype) !void {
    try validateHeader(fd, reader);

    try Cpu.restore(&fd.cpu, reader);
    try Mmu.restore(&fd.mmu, reader);
    try Timer.restore(&fd.timer, reader);

    fd.video.reset();
    try Video.restore(&fd.video, reader);
}
