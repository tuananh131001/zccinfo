const std = @import("std");
const git = @import("features/git.zig");
const path = @import("features/path.zig");
const model_module = @import("features/model.zig");
const version_module = @import("features/version.zig");
const context = @import("features/context.zig");

// ANSI color codes
const yellow = "\x1b[33m";
const magenta = "\x1b[35m";
const reset = "\x1b[0m";

// Display constants
const git_icon = "\u{e0a0}"; // Powerline git branch icon
const folder_icon = "\u{f07b}"; // Font Awesome folder icon (Nerd Font)
const model_icon = "🤖"; // Robot emoji for model display
const separator = " | ";

// Maximum input size (1MB should be plenty for JSON input)
const max_input_size = 1024 * 1024;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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

    // Format output by building segments dynamically
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    // Always write context percentage first
    writer.print("{s}Ctx: {d:.1}%{s}", .{ yellow, clamped_percentage, reset }) catch {
        std.debug.print("Error formatting output\n", .{});
        std.process.exit(1);
    };

    // Append each optional segment with separator
    if (git_status) |gs| {
        if (gs.branch) |branch| {
            writer.print("{s}{s}{s} {s}{s}", .{ separator, magenta, git_icon, branch, reset }) catch {};
        }
    }
    if (folder_name) |folder| {
        writer.print("{s}{s}{s} {s}{s}", .{ separator, magenta, folder_icon, folder, reset }) catch {};
    }
    if (model_display) |model| {
        writer.print("{s}{s} {s}{s}", .{ separator, model_icon, model, reset }) catch {};
    }
    if (version_display) |ver| {
        writer.print("{s}{s} {s}", .{ separator, version_module.version_icon, ver }) catch {};
    }
    writer.writeByte('\n') catch {};

    // Write to stdout
    std.fs.File.stdout().writeAll(fbs.getWritten()) catch |err| {
        std.debug.print("Error writing to stdout: {}\n", .{err});
        std.process.exit(1);
    };
}

fn readStdin(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.fs.File.stdin();
    return stdin.readToEndAlloc(allocator, max_input_size);
}
