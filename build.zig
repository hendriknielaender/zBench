const std = @import("std");
const log = std.log.scoped(.zbench_build);

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 2 };

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

fn setupLibrary(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode) *std.Build.LibExeObjStep {
    const lib = b.addStaticLibrary(.{
        .name = "zbench",
        .root_source_file = .{ .path = "zbench.zig" },
        .target = target,
        .optimize = optimize,
        .version = version,
    });

    b.installArtifact(lib);

    return lib;
}

fn setupTesting(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode) void {
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "zbench.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const test_dirs = [_][]const u8{ "util", "." };
    for (test_dirs) |dir| {
        addTestsFromDir(b, test_step, dir, target, optimize);
    }
}

fn addTestsFromDir(b: *std.Build, test_step: *std.Build.Step, dir_path: []const u8, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode) void {
    const iterableDir = std.fs.cwd().openIterableDir(dir_path, .{}) catch {
        log.warn("Failed to open directory: {s}", .{dir_path});
        return;
    };

    var it = iterableDir.iterate();
    while (true) {
        const optionalEntry = it.next() catch |err| {
            //TODO: break if access denied
            //if (err == std.fs.IterableDir.ChmodError) break;
            log.warn("Directory iteration error: {any}", .{err});
            continue;
        };

        if (optionalEntry == null) break; // No more entries

        const entry = optionalEntry.?;
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig")) {
            const test_path = std.fs.path.join(b.allocator, &[_][]const u8{ dir_path, entry.name }) catch continue;
            const test_name = std.fs.path.basename(test_path);

            const _test = b.addTest(.{
                .name = test_name,
                .root_source_file = .{ .path = test_path },
                .target = target,
                .optimize = optimize,
            });
            const run_test = b.addRunArtifact(_test);
            test_step.dependOn(&run_test.step);
        }
    }
}

fn setupExamples(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.OptimizeMode) void {
    const example_step = b.step("test_examples", "Build examples");
    const example_names = [_][]const u8{ "basic", "bubble_sort", "sleep" };

    for (example_names) |example_name| {
        const example = b.addTest(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        const install_example = b.addInstallArtifact(example, .{});
        const zbench_mod = b.addModule("zbench", .{ .source_file = .{ .path = "zbench.zig" } });
        example.addModule("zbench", zbench_mod);
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_example.step);
    }
}

fn setupDocumentation(b: *std.Build, lib: *std.Build.LibExeObjStep) void {
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);
}
