const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const subsystem = b.option(std.zig.Subsystem, "subsystem", "Subsystem to use") orelse
        if (target.result.os.tag == .windows and b.release_mode != .off) blk: {
            break :blk std.zig.Subsystem.windows;
        } else null;

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    const zlua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        .lang = .luajit,
    });

    const mod = b.addModule("branch", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "dvui", .module = dvui_dep.module("dvui_sdl3") },
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        },
    });
    mod.addAnonymousImport("branch.lua", .{
        .root_source_file = b.path("lua/branch.lua"),
    });

    const exe = b.addExecutable(.{
        .name = "branch",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "branch", .module = mod },
                .{ .name = "dvui", .module = dvui_dep.module("dvui_sdl3") },
                .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            },
        }),
    });
    exe.subsystem = subsystem;

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
