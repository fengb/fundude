const std = @import("std");

pub fn Matrix(comptime T: type, width: usize, height: usize) type {
    return packed struct {
        const Self = @This();

        data: [height * width]T,

        pub fn width(self: Self) usize {
            return width;
        }

        pub fn height(self: Self) usize {
            return height;
        }

        pub fn slice(self: *Self) MatrixSlice(T) {
            return MatrixSlice(T){
                .data = self.data[0..],
                .width = width,
                .height = height,
            };
        }

        pub fn reset(self: *Self, val: T) void {
            std.mem.set(T, self.data[0..], val);
        }

        pub fn get(self: Self, x: usize, y: usize) T {
            const i = self.idx(x, y);
            return self.data[i];
        }

        pub fn set(self: *Self, x: usize, y: usize, val: T) void {
            const i = self.idx(x, y);
            self.data[i] = val;
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
        data: [@memberCount(E)]T,

        fn get(self: @This(), tag: E) T {
            return self.data[@enumToInt(tag)];
        }

        fn set(self: *@This(), tag: E, value: T) void {
            self.data[@enumToInt(tag)] = value;
        }

        fn copy(self: *@This(), dst: E, src: E) void {
            self.set(dst, self.get(src));
        }
    };
}
