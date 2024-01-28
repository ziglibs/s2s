const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("s2s", .{
        .root_source_file = .{ .path = "s2s.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "s2s.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    const run_test = b.addRunArtifact(tests);
    test_step.dependOn(&run_test.step);
}
