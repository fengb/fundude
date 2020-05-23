const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("fundude", "src/c.zig");
    lib.setOutputDir("zig-cache");
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    b.default_step.dependOn(&lib.step);
    b.installArtifact(lib);

    addScript(b, "opcodes");
    addScript(b, "testrom");
    addScript(b, "smoke");
}

fn addScript(b: *std.build.Builder, name: []const u8) void {
    const filename = std.fmt.allocPrint(b.allocator, "scripts/{}.zig", .{name}) catch unreachable;
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable(name, filename);
    exe.setBuildMode(mode);
    exe.addPackagePath("fundude", "src/main.zig");

    const run_cmd = exe.run();
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(name, filename);
    run_step.dependOn(&run_cmd.step);
}
