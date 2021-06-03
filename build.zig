const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    //const lib = b.addStaticLibrary("fundude", "src/exports.zig");
    //lib.addPackagePath("zee_alloc", "submodules/zee_alloc/src/main.zig");
    //lib.setOutputDir("zig-cache");
    //lib.setBuildMode(mode);
    //lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });

    //var main_tests = b.addTest("src/main.zig");
    //main_tests.setBuildMode(mode);

    //const test_step = b.step("test", "Run library tests");
    //test_step.dependOn(&main_tests.step);

    //b.default_step.dependOn(&lib.step);
    //b.installArtifact(lib);

    var native = b.addExecutable("fundude_native", "src/native.zig");
    native.addPackagePath("zee_alloc", "submodules/zee_alloc/src/main.zig");
    native.linkSystemLibrary("sdl2");
    native.setTarget(target);
    native.setBuildMode(mode);
    native.install();

    const native_step = b.step("native", "Build native SDL version");
    native_step.dependOn(&native.step);

    const run_cmd = native.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    addScript(b, "opcodes");
    addScript(b, "testrom");
    addScript(b, "turbo");
}

fn addScript(b: *std.build.Builder, name: []const u8) void {
    const filename = std.fmt.allocPrint(b.allocator, "scripts/{s}.zig", .{name}) catch unreachable;
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
