const std = @import("std");
const log = std.log.scoped(.zbench_build);

const version = std.SemanticVersion{ .major = 0, .minor = 11, .patch = 2 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Setup library
    const lib = setupLibrary(b, target, optimize);

    // Setup testing
    setupTesting(b, target, optimize);

    // Setup examples
    setupExamples(b, target, optimize);

    // Setup documentation
    setupDocumentation(b, lib);
}

fn setupLibrary(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zbench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zbench.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .version = version,
    });

    b.installArtifact(lib);

    return lib;
}

fn setupTesting(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const test_files = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "partial", .path = "src/partial.zig" },
        .{ .name = "platform", .path = "src/platform/platform.zig" },
        .{ .name = "runner", .path = "src/runner.zig" },
        .{ .name = "statistics", .path = "src/statistics.zig" },
        .{ .name = "zbench", .path = "src/zbench.zig" },
    };

    const test_step = b.step("test", "Run library tests");
    for (test_files) |test_file| {
        const _test = b.addTest(.{
            .name = test_file.name,
            .root_module = b.createModule(.{
                .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = test_file.path } },
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_test = b.addRunArtifact(_test);
        test_step.dependOn(&run_test.step);
    }
}

fn setupExamples(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const example_step = b.step("examples", "Build examples");
    const example_names = [_][]const u8{
        "basic",
        "bubble_sort",
        "bubble_sort_hooks",
        "hooks",
        "json",
        "memory_tracking",
        "memory_comparison",
        "parameterised",
        "progress",
        "shuffling_allocator",
        "sleep",
        "systeminfo",
    };

    for (example_names) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_module = b.createModule(.{
                .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = b.fmt("examples/{s}.zig", .{example_name}) } },
                .target = target,
                .optimize = optimize,
            }),
        });
        const install_example = b.addInstallArtifact(example, .{});
        const zbench_mod = b.addModule("zbench", .{
            .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/zbench.zig" } },
        });
        example.root_module.addImport("zbench", zbench_mod);
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_example.step);
    }
}

fn setupDocumentation(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);
}
