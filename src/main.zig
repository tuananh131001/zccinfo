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

    // Format output with color
    var buf: [512]u8 = undefined;
    const output = if (git_status) |gs| blk: {
        if (gs.branch) |branch| {
            if (folder_name) |folder| {
                if (model_display) |model| {
                    if (version_display) |ver| {
                        // Full output: Ctx | git branch | folder | model | version
                        break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s}{s} {s}{s}{s}{s} {s}{s}{s}{s} {s}\n", .{
                            yellow,
                            clamped_percentage,
                            reset,
                            separator,
                            magenta,
                            git_icon,
                            branch,
                            reset,
                            separator,
                            magenta,
                            folder_icon,
                            folder,
                            reset,
                            separator,
                            model_icon,
                            model,
                            reset,
                            separator,
                            version_module.version_icon,
                            ver,
                        }) catch {
                            std.debug.print("Error formatting output\n", .{});
                            std.process.exit(1);
                        };
                    } else {
                        // Full output: Ctx | git branch | folder | model (no version)
                        break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s}{s} {s}{s}{s}{s} {s}{s}\n", .{
                            yellow,
                            clamped_percentage,
                            reset,
                            separator,
                            magenta,
                            git_icon,
                            branch,
                            reset,
                            separator,
                            magenta,
                            folder_icon,
                            folder,
                            reset,
                            separator,
                            model_icon,
                            model,
                            reset,
                        }) catch {
                            std.debug.print("Error formatting output\n", .{});
                            std.process.exit(1);
                        };
                    }
                } else {
                    // Output: Ctx | git branch | folder (no model)
                    break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s}{s} {s}{s}\n", .{
                        yellow,
                        clamped_percentage,
                        reset,
                        separator,
                        magenta,
                        git_icon,
                        branch,
                        reset,
                        separator,
                        magenta,
                        folder_icon,
                        folder,
                        reset,
                    }) catch {
                        std.debug.print("Error formatting output\n", .{});
                        std.process.exit(1);
                    };
                }
            } else {
                if (model_display) |model| {
                    if (version_display) |ver| {
                        // Output: Ctx | git branch | model | version
                        break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s} {s}{s}{s}{s} {s}\n", .{
                            yellow,
                            clamped_percentage,
                            reset,
                            separator,
                            magenta,
                            git_icon,
                            branch,
                            reset,
                            separator,
                            model_icon,
                            model,
                            reset,
                            separator,
                            version_module.version_icon,
                            ver,
                        }) catch {
                            std.debug.print("Error formatting output\n", .{});
                            std.process.exit(1);
                        };
                    } else {
                        // Output: Ctx | git branch | model (no version)
                        break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s} {s}{s}\n", .{
                            yellow,
                            clamped_percentage,
                            reset,
                            separator,
                            magenta,
                            git_icon,
                            branch,
                            reset,
                            separator,
                            model_icon,
                            model,
                            reset,
                        }) catch {
                            std.debug.print("Error formatting output\n", .{});
                            std.process.exit(1);
                        };
                    }
                } else {
                    // Output without folder: Ctx | git branch
                    break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}\n", .{
                        yellow,
                        clamped_percentage,
                        reset,
                        separator,
                        magenta,
                        git_icon,
                        branch,
                        reset,
                    }) catch {
                        std.debug.print("Error formatting output\n", .{});
                        std.process.exit(1);
                    };
                }
            }
        }
        break :blk null;
    } else null;

    const final_output = output orelse blk: {
        if (folder_name) |folder| {
            if (model_display) |model| {
                if (version_display) |ver| {
                    // Output: Ctx | folder | model | version
                    break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s} {s}{s}{s}{s} {s}\n", .{
                        yellow,
                        clamped_percentage,
                        reset,
                        separator,
                        magenta,
                        folder_icon,
                        folder,
                        reset,
                        separator,
                        model_icon,
                        model,
                        reset,
                        separator,
                        version_module.version_icon,
                        ver,
                    }) catch {
                        std.debug.print("Error formatting output\n", .{});
                        std.process.exit(1);
                    };
                } else {
                    // Output: Ctx | folder | model (no version)
                    break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}{s}{s} {s}{s}\n", .{
                        yellow,
                        clamped_percentage,
                        reset,
                        separator,
                        magenta,
                        folder_icon,
                        folder,
                        reset,
                        separator,
                        model_icon,
                        model,
                        reset,
                    }) catch {
                        std.debug.print("Error formatting output\n", .{});
                        std.process.exit(1);
                    };
                }
            } else {
                // Output with folder only: Ctx | folder
                break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s}{s} {s}{s}\n", .{
                    yellow,
                    clamped_percentage,
                    reset,
                    separator,
                    magenta,
                    folder_icon,
                    folder,
                    reset,
                }) catch {
                    std.debug.print("Error formatting output\n", .{});
                    std.process.exit(1);
                };
            }
        } else {
            if (model_display) |model| {
                if (version_display) |ver| {
                    // Output: Ctx | model | version
                    break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s} {s}{s}{s}{s} {s}\n", .{
                        yellow,
                        clamped_percentage,
                        reset,
                        separator,
                        model_icon,
                        model,
                        reset,
                        separator,
                        version_module.version_icon,
                        ver,
                    }) catch {
                        std.debug.print("Error formatting output\n", .{});
                        std.process.exit(1);
                    };
                } else {
                    // Output: Ctx | model (no version)
                    break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}{s}{s} {s}{s}\n", .{
                        yellow,
                        clamped_percentage,
                        reset,
                        separator,
                        model_icon,
                        model,
                        reset,
                    }) catch {
                        std.debug.print("Error formatting output\n", .{});
                        std.process.exit(1);
                    };
                }
            } else {
                // Minimal output: Ctx only
                break :blk std.fmt.bufPrint(&buf, "{s}Ctx: {d:.1}%{s}\n", .{
                    yellow,
                    clamped_percentage,
                    reset,
                }) catch {
                    std.debug.print("Error formatting output\n", .{});
                    std.process.exit(1);
                };
            }
        }
    };

    // Write to stdout
    std.fs.File.stdout().writeAll(final_output) catch |err| {
        std.debug.print("Error writing to stdout: {}\n", .{err});
        std.process.exit(1);
    };
}

fn readStdin(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.fs.File.stdin();
    return stdin.readToEndAlloc(allocator, max_input_size);
}
