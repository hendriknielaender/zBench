const std = @import("std");
const zine = @import("zine");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // CI passes -Dzine-system=true to consume the binary installed by
    // kristoff-it/setup-zine. Local dev defaults to building zine from
    // source (slow first run, cached afterwards).
    const use_system_zine = b.option(
        bool,
        "zine-system",
        "Use zine binary from PATH instead of building from source",
    ) orelse false;
    const zine_loc: @FieldType(zine.Options, "zine") =
        if (use_system_zine) .{ .path = null } else .source;

    // Pull autodocs from the parent zbench package so /api/ stays in sync
    // with the library source.
    const zbench_dep = b.dependency("zbench", .{
        .target = target,
        .optimize = optimize,
    });
    const docs_lp = zbench_dep.artifact("zbench").getEmittedDocs();

    const autodoc_assets = [_]zine.BuildAsset{
        .{ .name = "api/index.html", .lp = docs_lp.path(b, "index.html"), .install_path = "api/index.html", .install_always = true },
        .{ .name = "api/main.js", .lp = docs_lp.path(b, "main.js"), .install_path = "api/main.js", .install_always = true },
        .{ .name = "api/main.wasm", .lp = docs_lp.path(b, "main.wasm"), .install_path = "api/main.wasm", .install_always = true },
        .{ .name = "api/sources.tar", .lp = docs_lp.path(b, "sources.tar"), .install_path = "api/sources.tar", .install_always = true },
    };

    const site_run = zine.website(b, .{
        .website_root = b.path("."),
        .output_path = "site",
        .force = true,
        .zine = zine_loc,
        .build_assets = &autodoc_assets,
    });
    const site_step = b.step("site", "Build the Zine website with embedded autodocs");
    site_step.dependOn(&site_run.step);

    const serve_run = zine.serve(b, .{
        .website_root = b.path("."),
        .zine = zine_loc,
        .build_assets = &autodoc_assets,
    });
    const serve_step = b.step("serve", "Run the Zine dev server (http://localhost:1990)");
    serve_step.dependOn(&serve_run.step);
}
