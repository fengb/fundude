const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("fundude", "src/main.zig");
    lib.setOutputDir("zig-cache");
    lib.setBuildMode(mode);
    lib.setTarget(.wasm32, .freestanding, .musl);
    lib.linkSystemLibrary("c");
    lib.addIncludeDir("src");
    lib.addLibPath("vendor/wasi-sysroot/lib");

    var main_tests = b.addTest("src/fundude.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    b.default_step.dependOn(&lib.step);
    b.installArtifact(lib);
}
