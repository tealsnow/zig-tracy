const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // For example project tracy_enable defaults to true, but in real world projects tracy should never be on by default!
    // Better to enable it in debug builds - but disable for release.
    const tracy_enable = b.option(bool, "tracy_enable", "Enable profiling") orelse true;

    const tracy = b.dependency("tracy", .{
        .target = target,
        .optimize = optimize,
        .tracy_enable = tracy_enable,
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("tracy", tracy.module("tracy"));
    mod.linkLibrary(tracy.artifact("tracy"));
    mod.link_libcpp = true;

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
