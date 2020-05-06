const std = @import("std");

pub fn Matrix(comptime T: type, widt: usize, heigh: usize) type {
    return packed struct {
        const Self = @This();

        pub const width = widt;
        pub const height = heigh;

        data: [height * width]T align(@alignOf(T)),
        comptime width: usize = width,
        comptime height: usize = height,

        pub fn toArraySlice(self: *Self) []T {
            return &self.data;
        }

        pub fn toSlice(self: *Self) MatrixSlice(T) {
            return MatrixSlice(T){
                .data = self.toArraySlice(),
                .width = width,
                .height = height,
            };
        }

        pub fn reset(self: *Self, val: T) void {
            std.mem.set(T, &self.data, val);
        }

        pub fn get(self: Self, x: usize, y: usize) T {
            const i = self.idx(x, y);
            return self.data[i];
        }

        pub fn set(self: *Self, x: usize, y: usize, val: T) void {
            const i = self.idx(x, y);
            self.data[i] = val;
        }

        pub fn sliceLine(self: *Self, x: usize, y: usize) []T {
            const start = self.idx(x, y);
            const len = self.width - (x % self.width);
            return self.data[start .. start + len];
        }

        fn idx(self: Self, x: usize, y: usize) usize {
            std.debug.assert(x < width);
            std.debug.assert(y < height);
            return x + y * width;
        }
    };
}

pub fn MatrixSlice(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []T,
        width: usize,
        height: usize,

        pub fn get(self: Self, x: usize, y: usize) T {
            const i = self.idx(x, y);
            return self.data[i];
        }

        pub fn set(self: Self, x: usize, y: usize, val: T) void {
            const i = self.idx(x, y);
            self.data[i] = val;
        }

        pub fn sliceLine(self: *Self, x: usize, y: usize) []T {
            const start = self.idx(x, y);
            const len = self.width - (x % self.width);
            return self.data[start .. start + len];
        }

        fn idx(self: Self, x: usize, y: usize) usize {
            std.debug.assert(x < self.width);
            std.debug.assert(y < self.height);
            return x + y * self.width;
        }
    };
}

// Adapted from https://github.com/ziglang/zig/issues/793#issuecomment-482927820
pub fn EnumArray(comptime E: type, comptime T: type) type {
    return packed struct {
        const len = @typeInfo(E).Enum.fields.len;
        data: [len]T,

        fn get(self: @This(), tag: E) T {
            inline for (std.meta.fields(E)) |field| {
                if (field.value == @enumToInt(tag)) {
                    return self.data[field.value];
                }
            }
            unreachable;
            // return self.data[@enumToInt(tag)];
        }

        fn set(self: *@This(), tag: E, value: T) void {
            inline for (std.meta.fields(E)) |field| {
                if (field.value == @enumToInt(tag)) {
                    self.data[field.value] = value;
                    return;
                }
            }
            unreachable;
            // self.data[@enumToInt(tag)] = value;
        }

        fn copy(self: *@This(), dst: E, src: E) void {
            self.set(dst, self.get(src));
        }
    };
}
/// Super simple "perfect hash" algorithm
/// Only really useful for switching on strings
// TODO: can we auto detect and promote the underlying type?
pub fn Swhash(comptime max_bytes: comptime_int) type {
    const T = std.meta.IntType(false, max_bytes * 8);

    return struct {
        pub fn match(string: []const u8) T {
            return hash(string) orelse std.math.maxInt(T);
        }

        pub fn case(comptime string: []const u8) T {
            return hash(string) orelse @compileError("Cannot hash '" ++ string ++ "'");
        }

        fn hash(string: []const u8) ?T {
            if (string.len > max_bytes) return null;
            var tmp = [_]u8{0} ** max_bytes;
            std.mem.copy(u8, &tmp, string);
            return std.mem.readIntNative(T, &tmp);
        }
    };
}
