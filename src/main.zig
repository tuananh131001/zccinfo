const std = @import("std");
const git = @import("git.zig");
const path = @import("path.zig");

// ANSI color codes
const yellow = "\x1b[33m";
const magenta = "\x1b[35m";
const reset = "\x1b[0m";

// Display constants
const git_icon = "\u{e0a0}"; // Powerline git branch icon
const folder_icon = "\u{f07b}"; // Font Awesome folder icon (Nerd Font)
const separator = " | ";

// Maximum input size (1MB should be plenty for JSON input)
const max_input_size = 1024 * 1024;

// JSON structures for parsing stdin input
const Model = struct {
    id: ?[]const u8 = null,
};

const StatusInput = struct {
    model: ?Model = null,
    transcript_path: ?[]const u8 = null,
    cwd: ?[]const u8 = null,
};

// JSON structures for parsing JSONL transcript lines
const TokenUsage = struct {
    input_tokens: ?u64 = null,
    output_tokens: ?u64 = null,
    cache_read_input_tokens: ?u64 = null,
    cache_creation_input_tokens: ?u64 = null,
};

const Message = struct {
    usage: ?TokenUsage = null,
};

const TranscriptLine = struct {
    message: ?Message = null,
    isSidechain: ?bool = null,
    isApiErrorMessage: ?bool = null,
    timestamp: ?[]const u8 = null,
};

const ModelContextConfig = struct {
    max_tokens: u64,
};

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
    const parsed = std.json.parseFromSlice(StatusInput, allocator, stdin_input, .{
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.debug.print("Error parsing JSON: {}\n", .{err});
        std.process.exit(1);
    };
    defer parsed.deinit();

    const status = parsed.value;

    // Get transcript path
    const transcript_path = status.transcript_path orelse {
        std.debug.print("Error: transcript_path not provided in input\n", .{});
        std.process.exit(1);
    };

    // Parse JSONL transcript and get context length
    const context_length = getContextLength(allocator, transcript_path) catch |err| {
        std.debug.print("Error reading transcript: {}\n", .{err});
        std.process.exit(1);
    };

    // Get model ID and determine context config
    const model_id: ?[]const u8 = if (status.model) |m| m.id else null;
    const config = getContextConfig(allocator, model_id);

    // Calculate percentage
    const percentage = if (config.max_tokens > 0)
        @as(f64, @floatFromInt(context_length)) / @as(f64, @floatFromInt(config.max_tokens)) * 100.0
    else
        0.0;

    // Clamp to 100%
    const clamped_percentage = @min(percentage, 100.0);

    // Get git status (graceful if not in git repo)
    var git_status = git.getCurrentBranch(allocator);
    defer if (git_status) |*gs| gs.deinit();

    // Get folder name from cwd
    const folder_name = if (status.cwd) |cwd| path.basename(cwd) else null;

    // Format output with color
    var buf: [512]u8 = undefined;
    const output = if (git_status) |gs| blk: {
        if (gs.branch) |branch| {
            if (folder_name) |folder| {
                // Full output: Ctx | git branch | folder
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
        break :blk null;
    } else null;

    const final_output = output orelse blk: {
        if (folder_name) |folder| {
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

fn getContextLength(allocator: std.mem.Allocator, transcript_path: []const u8) !u64 {
    // Open the transcript file
    const file = std.fs.openFileAbsolute(transcript_path, .{}) catch |err| {
        // Try relative path if absolute fails
        const cwd = std.fs.cwd();
        const rel_file = cwd.openFile(transcript_path, .{}) catch {
            return err;
        };
        defer rel_file.close();
        return parseTranscriptFile(allocator, rel_file);
    };
    defer file.close();

    return parseTranscriptFile(allocator, file);
}

fn parseTranscriptFile(allocator: std.mem.Allocator, file: std.fs.File) !u64 {
    // Read entire file content
    const content = try file.readToEndAlloc(allocator, 100 * 1024 * 1024); // 100MB max
    defer allocator.free(content);

    var most_recent_timestamp: ?[]const u8 = null;
    var most_recent_context: u64 = 0;

    // Buffer for timestamp comparison
    var timestamp_buf: [64]u8 = undefined;
    var timestamp_len: usize = 0;

    // Split by newlines and process each line
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_content| {
        if (line_content.len == 0) continue;

        // Parse JSON line
        const parsed = std.json.parseFromSlice(TranscriptLine, allocator, line_content, .{
            .ignore_unknown_fields = true,
        }) catch continue; // Skip invalid JSON lines
        defer parsed.deinit();

        const entry = parsed.value;

        // Skip sidechain messages
        if (entry.isSidechain) |is_sidechain| {
            if (is_sidechain) continue;
        }

        // Skip API error messages
        if (entry.isApiErrorMessage) |is_error| {
            if (is_error) continue;
        }

        // Skip if no message or usage
        const message = entry.message orelse continue;
        const usage = message.usage orelse continue;

        // Calculate context length for this entry
        const input = usage.input_tokens orelse 0;
        const cache_read = usage.cache_read_input_tokens orelse 0;
        const cache_creation = usage.cache_creation_input_tokens orelse 0;
        const entry_context = input + cache_read + cache_creation;

        // Track most recent by timestamp
        if (entry.timestamp) |ts| {
            if (most_recent_timestamp == null or timestampGreater(ts, most_recent_timestamp.?)) {
                most_recent_context = entry_context;
                // Copy timestamp to buffer
                const copy_len = @min(ts.len, timestamp_buf.len);
                @memcpy(timestamp_buf[0..copy_len], ts[0..copy_len]);
                timestamp_len = copy_len;
                most_recent_timestamp = timestamp_buf[0..timestamp_len];
            }
        } else {
            // No timestamp, use as most recent if we don't have one
            if (most_recent_timestamp == null) {
                most_recent_context = entry_context;
            }
        }
    }

    return most_recent_context;
}

pub fn timestampGreater(a: []const u8, b: []const u8) bool {
    // ISO 8601 timestamps can be compared lexicographically
    return std.mem.order(u8, a, b) == .gt;
}

pub fn getContextConfig(allocator: std.mem.Allocator, model_id: ?[]const u8) ModelContextConfig {
    const default_config = ModelContextConfig{
        .max_tokens = 200_000,
    };

    const id = model_id orelse return default_config;

    // Convert to lowercase for case-insensitive matching
    const lower = allocator.alloc(u8, id.len) catch return default_config;
    defer allocator.free(lower);

    for (id, 0..) |c, i| {
        lower[i] = std.ascii.toLower(c);
    }

    // Check for Sonnet 4.5 with [1m] suffix
    const has_sonnet_45 = std.mem.indexOf(u8, lower, "claude-sonnet-4-5") != null;
    const has_1m_suffix = std.mem.indexOf(u8, lower, "[1m]") != null;

    if (has_sonnet_45 and has_1m_suffix) {
        return ModelContextConfig{
            .max_tokens = 1_000_000,
        };
    }

    return default_config;
}

test {
    _ = @import("main_test.zig");
}
