const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    const tracy_enable = option(b, options, bool, "tracy_enable", "Enable profiling", true);
    const tracy_on_demand = option(b, options, bool, "tracy_on_demand", "On-demand profiling", false);
    const tracy_callstack = callstack: {
        const opt = b.option(u8, "tracy_callstack", "Enforce callstack collection for tracy regions");
        options.addOption(?u8, "tracy_callstack", opt);
        break :callstack opt;
    };
    const tracy_no_callstack = option(b, options, bool, "tracy_no_callstack", "Disable all callstack related functionality", false);
    const tracy_no_callstack_inlines = option(b, options, bool, "tracy_no_callstack_inlines", "Disables the inline functions in callstacks", false);
    const tracy_only_localhost = option(b, options, bool, "tracy_only_localhost", "Only listen on the localhost interface", false);
    const tracy_no_broadcast = option(b, options, bool, "tracy_no_broadcast", "Disable client discovery by broadcast to local network", false);
    const tracy_only_ipv4 = option(b, options, bool, "tracy_only_ipv4", "Tracy will only accept connections on IPv4 addresses (disable IPv6)", false);
    const tracy_no_code_transfer = option(b, options, bool, "tracy_no_code_transfer", "Disable collection of source code", false);
    const tracy_no_context_switch = option(b, options, bool, "tracy_no_context_switch", "Disable capture of context switches", false);
    const tracy_no_exit = option(b, options, bool, "tracy_no_exit", "Client executable does not exit until all profile data is sent to server", false);
    const tracy_no_sampling = option(b, options, bool, "tracy_no_sampling", "Disable call stack sampling", false);
    const tracy_no_verify = option(b, options, bool, "tracy_no_verify", "Disable zone validation for C API", false);
    const tracy_no_vsync_capture = option(b, options, bool, "tracy_no_vsync_capture", "Disable capture of hardware Vsync events", false);
    const tracy_no_frame_image = option(b, options, bool, "tracy_no_frame_image", "Disable the frame image support and its thread", false);
    // @FIXME: For some reason system tracing crashes the program, will need to investigate
    //  panics during some drawf thing within libbacktrace (c++)
    const tracy_no_system_tracing = option(b, options, bool, "tracy_no_system_tracing", "Disable systrace sampling", true);
    const tracy_delayed_init = option(b, options, bool, "tracy_delayed_init", "Enable delayed initialization of the library (init on first call)", false);
    const tracy_manual_lifetime = option(b, options, bool, "tracy_manual_lifetime", "Enable the manual lifetime management of the profile", false);
    const tracy_fibers = option(b, options, bool, "tracy_fibers", "Enable fibers support", false);
    const tracy_no_crash_handler = option(b, options, bool, "tracy_no_crash_handler", "Disable crash handling", false);
    const tracy_timer_fallback = option(b, options, bool, "tracy_timer_fallback", "Use lower resolution timers", false);
    const shared = option(b, options, bool, "shared", "Build the tracy client as a shared libary", false);

    const c_tracy = b.dependency("tracy_lib", .{});

    const mod = b.addModule("tracy", .{
        .root_source_file = b.path("src/tracy.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "tracy-options",
                .module = options.createModule(),
            },
        },
    });

    // Avoid building Tracy completely if it is disabled.

    if (tracy_enable) {
        mod.addIncludePath(c_tracy.path("public"));

        if (target.result.os.tag == .windows) {
            mod.linkSystemLibrary("dbghelp", .{ .needed = true });
            mod.linkSystemLibrary("ws2_32", .{ .needed = true });
        }
        mod.link_libcpp = true;
        mod.addCSourceFile(.{
            .file = c_tracy.path("public/TracyClient.cpp"),
        });

        if (tracy_enable) mod.addCMacro("TRACY_ENABLE", "");
        if (tracy_on_demand) mod.addCMacro("TRACY_ON_DEMAND", "");
        if (tracy_callstack) |depth| mod.addCMacro(b.fmt("TRACY_CALLSTACK \"{d}\"", .{depth}), "");
        if (tracy_no_callstack) mod.addCMacro("TRACY_NO_CALLSTACK", "");
        if (tracy_no_callstack_inlines) mod.addCMacro("TRACY_NO_CALLSTACK_INLINES", "");
        if (tracy_only_localhost) mod.addCMacro("TRACY_ONLY_LOCALHOST", "");
        if (tracy_no_broadcast) mod.addCMacro("TRACY_NO_BROADCAST", "");
        if (tracy_only_ipv4) mod.addCMacro("TRACY_ONLY_IPV4", "");
        if (tracy_no_code_transfer) mod.addCMacro("TRACY_NO_CODE_TRANSFER", "");
        if (tracy_no_context_switch) mod.addCMacro("TRACY_NO_CONTEXT_SWITCH", "");
        if (tracy_no_exit) mod.addCMacro("TRACY_NO_EXIT", "");
        if (tracy_no_sampling) mod.addCMacro("TRACY_NO_SAMPLING", "");
        if (tracy_no_verify) mod.addCMacro("TRACY_NO_VERIFY", "");
        if (tracy_no_vsync_capture) mod.addCMacro("TRACY_NO_VSYNC_CAPTURE", "");
        if (tracy_no_frame_image) mod.addCMacro("TRACY_NO_FRAME_IMAGE", "");
        if (tracy_no_system_tracing) mod.addCMacro("TRACY_NO_SYSTEM_TRACING", "");
        if (tracy_delayed_init) mod.addCMacro("TRACY_DELAYED_INIT", "");
        if (tracy_manual_lifetime) mod.addCMacro("TRACY_MANUAL_LIFETIME", "");
        if (tracy_fibers) mod.addCMacro("TRACY_FIBERS", "");
        if (tracy_no_crash_handler) mod.addCMacro("TRACY_NO_CRASH_HANDLER", "");
        if (tracy_timer_fallback) mod.addCMacro("TRACY_TIMER_FALLBACK", "");
        if (shared and target.result.os.tag == .windows) mod.addCMacro("TRACY_EXPORTS", "");

        const lib = b.addLibrary(.{
            .linkage = if (shared) .dynamic else .static,
            .name = "tracy",
            .root_module = mod,
        });

        b.installArtifact(lib);
    }
}

pub fn option(
    b: *std.Build,
    options: *std.Build.Step.Options,
    comptime T: type,
    name_raw: []const u8,
    description_raw: []const u8,
    default: T,
) T {
    const opt = b.option(T, name_raw, description_raw) orelse default;
    options.addOption(T, name_raw, opt);
    return opt;
}
