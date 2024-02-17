const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const tests = b.option(bool, "Tests", "Build tests [default: false]") orelse false;

    const lib = b.addStaticLibrary(.{
        .name = "benchmark",
        .target = target,
        .optimize = optimize,
    });
    lib.defineCMacro("BENCHMARK_VERSION", "0");
    lib.addIncludePath(.{ .path = "src" });
    lib.addIncludePath(.{ .path = "include" });
    lib.addCSourceFiles(.{
        .files = &.{
            "src/benchmark.cc",
            "src/benchmark_api_internal.cc",
            "src/benchmark_name.cc",
            "src/benchmark_register.cc",
            "src/benchmark_runner.cc",
            "src/check.cc",
            "src/colorprint.cc",
            "src/commandlineflags.cc",
            "src/complexity.cc",
            "src/console_reporter.cc",
            "src/counter.cc",
            "src/csv_reporter.cc",
            "src/json_reporter.cc",
            "src/perf_counters.cc",
            "src/reporter.cc",
            "src/statistics.cc",
            "src/string_util.cc",
            "src/sysinfo.cc",
            "src/timers.cc",
        },
        .flags = cxxflags,
    });
    lib.pie = true;
    lib.installHeadersDirectory("include", "");

    const libMain = b.addStaticLibrary(.{
        .name = "benchmark_main",
        .target = target,
        .optimize = optimize,
    });
    libMain.addIncludePath(.{ .path = "src" });
    libMain.addIncludePath(.{ .path = "include" });
    libMain.addCSourceFile(.{ .file = .{ .path = "src/benchmark_main.cc" }, .flags = cxxflags });
    libMain.pie = true;
    if (lib.rootModuleTarget().abi == .msvc) {
        lib.linkLibC();
        libMain.linkLibC();
    } else {
        lib.linkLibCpp();
        libMain.linkLibCpp();
    }

    b.installArtifact(lib);
    b.installArtifact(libMain);

    if (tests) {
        buildExe(b, .{
            .path = "test/basic_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/benchmark_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/complexity_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/filter_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/link_main_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/map_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/internal_threading_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
        buildExe(b, .{
            .path = "test/diagnostics_test.cc",
            .libs = &[_]*std.Build.Step.Compile{ lib, libMain },
        });
    }
}

fn buildExe(b: *std.Build, property: BuildInfo) void {
    const exe = b.addExecutable(.{
        .name = property.filename(),
        .target = property.libs[0].root_module.resolved_target.?,
        .optimize = property.libs[0].root_module.optimize.?,
    });
    for (property.libs[0].root_module.include_dirs.items) |dir| {
        exe.root_module.include_dirs.append(b.allocator, dir) catch {};
    }
    exe.addCSourceFile(.{ .file = .{ .path = property.path }, .flags = cxxflags });

    exe.linkLibrary(property.libs[0]);
    if (std.mem.startsWith(u8, property.filename(), "link_main"))
        exe.linkLibrary(property.libs[1]);
    if (std.mem.startsWith(u8, property.filename(), "complexity") or std.mem.startsWith(u8, property.filename(), "internal")) {
        exe.addCSourceFile(.{ .file = .{ .path = "test/output_test_helper.cc" }, .flags = cxxflags });
    }
    if (exe.rootModuleTarget().abi == .msvc) {
        exe.linkLibC();
    } else {
        exe.linkLibCpp();
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(
        property.filename(),
        b.fmt("Run the {s} test", .{property.filename()}),
    );
    run_step.dependOn(&run_cmd.step);
}

const BuildInfo = struct {
    libs: []const *std.Build.Step.Compile,
    path: []const u8,

    fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.splitSequence(u8, std.fs.path.basename(self.path), ".");
        return split.first();
    }
};
const cxxflags = &.{
    "-Wall",
    "-Wextra",
    "-Wshadow",
    "-Wfloat-equal",
    "-pedantic",
    "-Wold-style-cast",
    "-fstrict-aliasing",
    "-pedantic-errors",
};
