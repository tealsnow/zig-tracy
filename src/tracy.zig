const std = @import("std");
const builtin = @import("builtin");
pub const options = @import("tracy-options");
const c = if (options.tracy_enable) @cImport({
    if (options.tracy_enable) @cDefine("TRACY_ENABLE", {});
    if (options.tracy_on_demand) @cDefine("TRACY_ON_DEMAND", {});
    if (options.tracy_callstack) |depth| @cDefine("TRACY_CALLSTACK", std.fmt.comptimePrint("\"{}\"", .{depth}));
    if (options.tracy_no_callstack) @cDefine("TRACY_NO_CALLSTACK", {});
    if (options.tracy_no_callstack_inlines) @cDefine("TRACY_NO_CALLSTACK_INLINES", {});
    if (options.tracy_only_localhost) @cDefine("TRACY_ONLY_LOCALHOST", {});
    if (options.tracy_no_broadcast) @cDefine("TRACY_NO_BROADCAST", {});
    if (options.tracy_only_ipv4) @cDefine("TRACY_ONLY_IPV4", {});
    if (options.tracy_no_code_transfer) @cDefine("TRACY_NO_CODE_TRANSFER", {});
    if (options.tracy_no_context_switch) @cDefine("TRACY_NO_CONTEXT_SWITCH", {});
    if (options.tracy_no_exit) @cDefine("TRACY_NO_EXIT", {});
    if (options.tracy_no_sampling) @cDefine("TRACY_NO_SAMPLING", {});
    if (options.tracy_no_verify) @cDefine("TRACY_NO_VERIFY", {});
    if (options.tracy_no_vsync_capture) @cDefine("TRACY_NO_VSYNC_CAPTURE", {});
    if (options.tracy_no_frame_image) @cDefine("TRACY_NO_FRAME_IMAGE", {});
    if (options.tracy_no_system_tracing) @cDefine("TRACY_NO_SYSTEM_TRACING", {});
    if (options.tracy_delayed_init) @cDefine("TRACY_DELAYED_INIT", {});
    if (options.tracy_manual_lifetime) @cDefine("TRACY_MANUAL_LIFETIME", {});
    if (options.tracy_fibers) @cDefine("TRACY_FIBERS", {});
    if (options.tracy_no_crash_handler) @cDefine("TRACY_NO_CRASH_HANDLER", {});
    if (options.tracy_timer_fallback) @cDefine("TRACY_TIMER_FALLBACK", {});
    if (options.shared and builtin.os.tag == .windows) @cDefine("TRACY_IMPORTS", {});

    @cInclude("tracy/TracyC.h");
}) else void;

//= format

const tracy_message_buffer_size = if (options.tracy_enable) 4096 else 0;
threadlocal var tracy_message_buffer: [tracy_message_buffer_size]u8 = undefined;

inline fn format(comptime fmt: []const u8, args: anytype) [:0]const u8 {
    return std.fmt.bufPrintZ(&tracy_message_buffer, fmt, args) catch {
        std.log.warn("formated text larger than {} bytes", .{tracy_message_buffer_size});
        std.log.warn("message:", .{});
        std.log.warn(fmt, args);
        return "<message too large>";
    };
}

//= connection

pub inline fn startupProfiler() void {
    if (!options.tracy_enable) return;
    if (!options.tracy_manual_lifetime) return;
    c.___tracy_startup_profiler();
}

pub inline fn shutdownProfiler() void {
    if (!options.tracy_enable) return;
    if (!options.tracy_manual_lifetime) return;
    c.___tracy_shutdown_profiler();
}

pub inline fn isConnected() bool {
    if (!options.tracy_enable) return false;
    return c.___tracy_connected() > 0;
}

//= print info

pub inline fn setThreadName(name: [:0]const u8) void {
    if (!options.tracy_enable) return;
    c.___tracy_set_thread_name(name);
}

pub inline fn printAppInfo(comptime fmt: []const u8, args: anytype) void {
    if (!options.tracy_enable) return;

    const string = format(fmt, args);
    c.___tracy_emit_message_appinfo(string.ptr, string.len);
}

pub inline fn message(comptime fmt: []const u8, args: anytype) void {
    if (!options.tracy_enable) return;
    const depth = options.tracy_callstack orelse 0;

    const string = format(fmt, args);
    c.___tracy_emit_message(string.ptr, string.len, depth);
}

pub inline fn messageColor(comptime fmt: []const u8, args: anytype, color: u32) void {
    if (!options.tracy_enable) return;
    const depth = options.tracy_callstack orelse 0;

    const string = format(fmt, args);
    c.___tracy_emit_messageC(string.ptr, string.len, color, depth);
}

//= frames

pub inline fn frameMark() void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_frame_mark(null);
}

pub inline fn frameMarkNamed(name: [:0]const u8) void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_frame_mark(name);
}

pub const DiscontinuousFrame = struct {
    name: [:0]const u8,

    pub inline fn end(frame: *const DiscontinuousFrame) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_frame_mark_end(frame.name);
    }
};

pub inline fn startDiscontinuousFrame(name: [:0]const u8) DiscontinuousFrame {
    if (!options.tracy_enable) return .{ .name = "" };
    c.___tracy_emit_frame_mark_start(name);
    return .{ .name = name };
}

pub inline fn frameImage(image: *anyopaque, width: u16, height: u16, offset: u8, flip: bool) void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_frame_image(image, width, height, offset, @as(c_int, @intFromBool(flip)));
}

//= zones

pub const ZoneOptions = struct {
    active: bool = true,
    name: ?[]const u8 = null,
    color: ?u32 = null,
};

pub const ZoneContext = struct {
    ctx: if (options.tracy_enable) c.___tracy_c_zone_context else void,

    pub inline fn end(zone: ZoneContext) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_end(zone.ctx);
    }

    pub inline fn name(zone: ZoneContext, comptime fmt: []const u8, args: anytype) void {
        if (!options.tracy_enable) return;
        const string = format(fmt, args);
        c.___tracy_emit_zone_name(zone.ctx, string.ptr, string.len);
    }

    pub inline fn text(zone: ZoneContext, comptime fmt: []const u8, args: anytype) void {
        if (!options.tracy_enable) return;
        const string = format(fmt, args);
        c.___tracy_emit_zone_text(zone.ctx, string.ptr, string.len);
    }

    pub inline fn color(zone: ZoneContext, zone_color: u32) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_color(zone.ctx, zone_color);
    }

    pub inline fn value(zone: ZoneContext, zone_value: u64) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_value(zone.ctx, zone_value);
    }
};

pub inline fn beginZone(comptime src: std.builtin.SourceLocation, opts: ZoneOptions) ZoneContext {
    if (!options.tracy_enable) return .{ .ctx = void{} };
    const active: c_int = @intFromBool(opts.active);

    const src_loc = c.___tracy_source_location_data{
        .name = if (opts.name) |name| name.ptr else null,
        .function = src.fn_name.ptr,
        .file = src.file,
        .line = src.line,
        .color = opts.color orelse 0,
    };

    if (!options.tracy_no_callstack) {
        if (options.tracy_callstack) |depth| {
            return .{
                .ctx = c.___tracy_emit_zone_begin_callstack(&src_loc, depth, active),
            };
        }
    }

    return .{
        .ctx = c.___tracy_emit_zone_begin(&src_loc, active),
    };
}

//= plots

pub const PlotType = enum(c.TracyPlotFormatEnum) {
    Number = c.TracyPlotFormatNumber,
    Memory = c.TracyPlotFormatMemory,
    Percentage = c.TracyPlotFormatPercentage,
    Watt = c.TracyPlotFormatWatt,
};

pub const PlotConfig = struct {
    plot_type: PlotType,
    step: c_int,
    fill: c_int,
    color: u32,
};

pub inline fn plotConfig(name: [:0]const u8, config: PlotConfig) void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_plot_config(
        name,
        @intFromEnum(config.plot_type),
        config.step,
        config.fill,
        config.color,
    );
}

pub inline fn plot(name: [:0]const u8, value: anytype) void {
    if (!options.tracy_enable) return;

    const type_info = @typeInfo(@TypeOf(value));
    switch (type_info) {
        .int => |int_type| {
            if (int_type.bits > 64) @compileError("Too large int to plot");
            if (int_type.signedness == .unsigned and int_type.bits > 63) @compileError("Too large unsigned int to plot");
            c.___tracy_emit_plot_int(name, @intCast(value));
        },
        .float => |float_type| {
            if (float_type.bits <= 32) {
                c.___tracy_emit_plot_float(name, @floatCast(value));
            } else if (float_type.bits <= 64) {
                c.___tracy_emit_plot(name, @floatCast(value));
            } else {
                @compileError("Too large float to plot");
            }
        },
        else => @compileError("Unsupported plot value type"),
    }
}

//= allocators

pub const TracingAllocator = struct {
    pool_name: ?[:0]const u8,
    backing_allocator: std.mem.Allocator,

    const Self = @This();
    const Alignment = std.mem.Alignment;

    pub fn init(backing_allocator: std.mem.Allocator) Self {
        return .{
            .pool_name = null,
            .backing_allocator = backing_allocator,
        };
    }

    pub fn initNamed(pool_name: [:0]const u8, backing_allocator: std.mem.Allocator) Self {
        return .{
            .pool_name = pool_name,
            .backing_allocator = backing_allocator,
        };
    }

    pub fn discard(self: *Self) void {
        if (!options.tracy_enable) return;

        if (self.pool_name) |name| {
            c.___tracy_emit_memory_discard(name.ptr, 0);
        } else {
            c.___tracy_emit_memory_discard(null, 0);
        }
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.backing_allocator.rawAlloc(len, alignment, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_alloc_named(result, len, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_alloc(result, len, 0);
            }
        }

        return result;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.backing_allocator.rawResize(memory, alignment, new_len, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_free_named(memory.ptr, 0, name.ptr);
                c.___tracy_emit_memory_alloc_named(memory.ptr, new_len, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_free(memory.ptr, 0);
                c.___tracy_emit_memory_alloc(memory.ptr, new_len, 0);
            }
        }

        return result;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.backing_allocator.rawRemap(memory, alignment, new_len, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_free_named(memory.ptr, 0, name.ptr);
                c.___tracy_emit_memory_alloc_named(memory.ptr, new_len, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_free(memory.ptr, 0);
                c.___tracy_emit_memory_alloc(memory.ptr, new_len, 0);
            }
        }

        return result;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.backing_allocator.rawFree(memory, alignment, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_free_named(memory.ptr, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_free(memory.ptr, 0);
            }
        }
    }
};
