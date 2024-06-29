const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = .ReleaseFast;

    const serial = b.dependency("serial", .{ .target = target, });

    const exe = b.addExecutable(.{
        .name = "LightMatrix",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("serial", serial.module("serial"));
    b.installArtifact(exe);
}
