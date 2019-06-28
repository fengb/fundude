const std = @import("std");

pub fn Matrix(comptime T: type, width: usize, height: usize) type {
    return struct {
        const Self = @This();

        array: [height * width]T,
        width: usize = width,
        height: usize = height,

        slice: MatrixSlice(T) = MatrixSlice(T){
            .slice = array[0..],
            .width = width,
            .height = height,
        },

        pub fn setAll(self: *Self, val: T) void {
            std.mem.set(T, self.array[0..], val);
        }

        pub fn get(self: Self, x: usize, y: usize) T {
            return self.slice.get(x, y);
        }

        pub fn set(self: Self, x: usize, y: usize, val: T) void {
            return self.slice.set(x, y, val);
        }
    };
}

pub fn MatrixSlice(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []T,
        width: usize,
        height: usize,

        pub fn get(self: Self, x: usize, y: usize) T {
            const i = self.idx(x, y);
            return self.slice[i];
        }

        pub fn set(self: Self, x: usize, y: usize, val: T) void {
            const i = self.idx(x, y);
            self.slice[i] = val;
        }

        fn idx(self: Self, x: usize, y: usize) usize {
            return x + y * self.width;
        }
    };
}
