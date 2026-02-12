const std = @import("std");
const git = @import("features/git.zig");
const path = @import("features/path.zig");
const model_module = @import("features/model.zig");
const version_module = @import("features/version.zig");
const context = @import("features/context.zig");
const config_module = @import("features/config.zig");
const format_module = @import("features/format.zig");

const reset = config_module.reset;

// Maximum input size (1MB should be plenty for JSON input)
const max_input_size = 1024 * 1024;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration (falls back to defaults on any error)
    const config = config_module.loadConfig();

    // Read stdin
    const stdin_input = readStdin(allocator) catch |err| {
        std.debug.print("Error reading stdin: {}\n", .{err});
        std.process.exit(1);
    };
    defer allocator.free(stdin_input);

    if (stdin_input.len == 0) {
        std.debug.print("Error: No input received on stdin\n", .{});
        std.process.exit(1);
    }

    // Parse JSON input
    const parsed = std.json.parseFromSlice(context.StatusInput, allocator, stdin_input, .{
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.debug.print("Error parsing JSON: {}\n", .{err});
        std.process.exit(1);
    };
    defer parsed.deinit();

    const status = parsed.value;

    // Get context usage percentage from Claude Code's pre-calculated field
    const clamped_percentage: f64 = if (status.context_window) |cw|
        @min(cw.used_percentage orelse 0.0, 100.0)
    else
        0.0;

    // Get git status (graceful if not in git repo)
    var git_status = git.getCurrentBranch(allocator);
    defer if (git_status) |*gs| gs.deinit();

    // Get folder name from cwd
    const folder_name = if (status.cwd) |cwd| path.basename(cwd) else null;

    // Get model display string
    var model_display_buf: [64]u8 = undefined;
    const model_display: ?[]const u8 = if (status.model) |m|
        model_module.formatDisplayString(&model_display_buf, m)
    else
        null;

    // Get version display string
    var version_display_buf: [32]u8 = undefined;
    const version_display: ?[]const u8 = if (status.version) |v|
        version_module.formatVersion(&version_display_buf, v)
    else
        null;

    // Build each segment's display string using config colors/icons
    var ctx_seg_buf: [128]u8 = undefined;
    var git_seg_buf: [128]u8 = undefined;
    var folder_seg_buf: [128]u8 = undefined;
    var model_seg_buf: [128]u8 = undefined;
    var version_seg_buf: [128]u8 = undefined;

    const values = format_module.SegmentValues{
        .context = if (config.context.enabled)
            buildContextSegment(&ctx_seg_buf, clamped_percentage, &config)
        else
            null,
        .git = if (config.git.enabled)
            buildSegment(&git_seg_buf, getGitBranch(git_status), config.git)
        else
            null,
        .folder = if (config.folder.enabled)
            buildSegment(&folder_seg_buf, folder_name, config.folder)
        else
            null,
        .model = if (config.model.enabled)
            buildSegment(&model_seg_buf, model_display, config.model)
        else
            null,
        .version = if (config.version.enabled)
            buildSegment(&version_seg_buf, version_display, config.version)
        else
            null,
    };

    // Tokenize format string and render
    const tokens = format_module.tokenize(config.getFormat());

    var out_buf: [512]u8 = undefined;
    const output = format_module.render(&out_buf, &tokens, &values);

    // Write output + newline to stdout
    const stdout = std.fs.File.stdout();
    stdout.writeAll(output) catch |err| {
        std.debug.print("Error writing to stdout: {}\n", .{err});
        std.process.exit(1);
    };
    stdout.writeAll("\n") catch {};
}

fn getGitBranch(git_status: ?git.GitStatus) ?[]const u8 {
    if (git_status) |gs| {
        return gs.branch;
    }
    return null;
}

fn buildContextSegment(buf: []u8, percentage: f64, config: *const config_module.Config) ?[]const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();

    const color = config.context.color.toAnsi();
    const has_color = color.len > 0;
    const icon = config.context.icon;

    if (has_color) writer.writeAll(color) catch return null;
    if (icon.len > 0) {
        writer.writeAll(icon) catch return null;
        writer.writeByte(' ') catch return null;
    }
    writer.writeAll(config.context.prefix) catch return null;
    writer.print("{d:.1}", .{percentage}) catch return null;
    writer.writeAll(config.context.suffix) catch return null;
    if (has_color) writer.writeAll(reset) catch return null;

    return fbs.getWritten();
}

fn buildSegment(buf: []u8, value: ?[]const u8, seg: config_module.SegmentConfig) ?[]const u8 {
    const val = value orelse return null;

    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();

    const color = seg.color.toAnsi();
    const has_color = color.len > 0;
    const icon = seg.icon;

    if (has_color) writer.writeAll(color) catch return null;
    if (icon.len > 0) {
        writer.writeAll(icon) catch return null;
        writer.writeByte(' ') catch return null;
    }
    writer.writeAll(val) catch return null;
    if (has_color) writer.writeAll(reset) catch return null;

    return fbs.getWritten();
}

fn readStdin(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.fs.File.stdin();
    return stdin.readToEndAlloc(allocator, max_input_size);
}
