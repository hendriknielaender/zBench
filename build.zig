const std = @import("std");
const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zbench",
        .root_source_file = .{ .path = "zbench.zig" },
        .target = target,
        .optimize = optimize,
        .version = version,
    });

    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "zbench.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Add tests from the 'util' directory
    addTestDir(b, test_step, "./util", target, b.allocator);

    const zbench_mod = b.addModule("zbench", .{ .source_file = .{ .path = "zbench.zig" } });

    const example_step = b.step("test_examples", "Build examples");
    // Add new examples here
    for ([_][]const u8{ "basic", "bubble_sort", "sleep" }) |example_name| {
        const example = b.addTest(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        const install_example = b.addInstallArtifact(example, .{});
        example.addModule("zbench", zbench_mod);
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_example.step);
    }

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);
}

fn addTestDir(b: *std.Build, test_step: *std.Build.Step, dir_path: []const u8, target: std.zig.CrossTarget, allocator: std.mem.Allocator) void {
    const dir = std.fs.cwd().openIterableDir(dir_path, .{}) catch return;
    var iter = dir.iterate();
    while (true) {
        const optionalEntry = iter.next() catch |err| {
            std.debug.print("Directory iteration error: {}\n", .{err});
            continue;
        };

        if (optionalEntry == null) break; // No more entries

        const entry = optionalEntry.?;
        switch (entry.kind) {
            .file => {
                if (std.mem.endsWith(u8, entry.name, ".zig")) {
                    const test_path = std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name }) catch continue;

                    // Create TestOptions struct with the test path
                    const test_options = std.Build.TestOptions{
                        .root_source_file = .{ .path = test_path },
                        .target = target,
                    };

                    const test_file = b.addTest(test_options);
                    test_step.dependOn(&test_file.step);
                }
            },
            .directory => {
                const sub_path = std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name }) catch continue;
                addTestDir(b, test_step, sub_path, target, allocator);
            },
            else => continue,
        }
    }
}
