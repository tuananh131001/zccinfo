const std = @import("std");
const toml = @import("toml");

/// ANSI color codes
pub const Color = enum {
    none,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    pub fn toAnsi(self: Color) []const u8 {
        return switch (self) {
            .none => "",
            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
        };
    }

    pub fn fromString(s: []const u8) Color {
        const map = .{
            .{ "black", .black },
            .{ "red", .red },
            .{ "green", .green },
            .{ "yellow", .yellow },
            .{ "blue", .blue },
            .{ "magenta", .magenta },
            .{ "cyan", .cyan },
            .{ "white", .white },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, s, entry[0])) return entry[1];
        }
        return .none;
    }
};

pub const reset = "\x1b[0m";

/// Configuration for a standard segment (git, folder, model, version)
pub const SegmentConfig = struct {
    enabled: bool = true,
    color: Color = .none,
    icon: []const u8 = "",
};

/// Configuration for the context segment (has additional prefix/suffix)
pub const ContextSegmentConfig = struct {
    enabled: bool = true,
    color: Color = .yellow,
    icon: []const u8 = "",
    prefix: []const u8 = "Ctx: ",
    suffix: []const u8 = "%",
};

/// Maximum length for the format string
const max_format_len = 256;

/// Full configuration
pub const Config = struct {
    format_buf: [max_format_len]u8 = undefined,
    format_len: usize = 0,
    context: ContextSegmentConfig = .{},
    git: SegmentConfig = .{ .color = .magenta, .icon = "\u{e0a0}" },
    folder: SegmentConfig = .{ .color = .magenta, .icon = "\u{f07b}" },
    model: SegmentConfig = .{ .icon = "\u{1F916}" }, // 🤖
    version: SegmentConfig = .{ .icon = "\u{1F4E6}" }, // 📦

    pub fn getFormat(self: *const Config) []const u8 {
        if (self.format_len > 0) {
            return self.format_buf[0..self.format_len];
        }
        return default_format;
    }
};

const default_format = "{context} | {git} | {folder} | {model} | {version}";

/// Default configuration matching current hardcoded behavior
pub const default_config = Config{};

/// Default configuration file content (embedded at comptime from docs/config-example.toml)
const default_config_toml = @embedFile("config-example.toml");

/// Size of the file read buffer
const file_buf_size = 4096;

/// Load configuration from ~/.claude/zccinfo/config.toml.
/// Copies the default config file to the destination if it does not exist.
/// Returns default config on any error (file not found, parse error, etc.)
pub fn loadConfig() Config {
    // Build config path: ~/.claude/zccinfo/config.toml
    const home = std.posix.getenv("HOME") orelse return default_config;

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const config_path = std.fmt.bufPrint(&path_buf, "{s}/.claude/zccinfo/config.toml", .{home}) catch
        return default_config;

    // Read file into stack buffer
    var file_buf: [file_buf_size]u8 = undefined;
    const file = std.fs.cwd().openFile(config_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            copyDefaultConfig(config_path);
        }
        return default_config;
    };
    defer file.close();

    const bytes_read = file.readAll(&file_buf) catch return default_config;
    const source = file_buf[0..bytes_read];

    // Parse TOML
    const table = toml.parse(source) catch return default_config;

    return parseConfig(&table);
}

/// Copy the default config file to the given path, creating parent directories as needed.
fn copyDefaultConfig(config_path: []const u8) void {
    if (std.fs.path.dirname(config_path)) |dir_path| {
        std.fs.cwd().makePath(dir_path) catch return;
    }
    const file = std.fs.cwd().createFile(config_path, .{}) catch return;
    defer file.close();
    file.writeAll(default_config_toml) catch return;
}

/// Parse a TomlTable into a Config, filling missing keys with defaults.
pub fn parseConfig(table: *const toml.TomlTable) Config {
    var config = default_config;

    // Top-level format string
    if (table.getString("format")) |fmt| {
        if (fmt.len <= max_format_len) {
            @memcpy(config.format_buf[0..fmt.len], fmt);
            config.format_len = fmt.len;
        }
    }

    // Context segment
    parseContextSegment(table, &config.context);

    // Standard segments
    parseSegment(table, "git", &config.git);
    parseSegment(table, "folder", &config.folder);
    parseSegment(table, "model", &config.model);
    parseSegment(table, "version", &config.version);

    return config;
}

fn parseContextSegment(table: *const toml.TomlTable, seg: *ContextSegmentConfig) void {
    if (table.getBool("context.enabled")) |v| seg.enabled = v;
    if (table.getString("context.color")) |v| seg.color = Color.fromString(v);
    if (table.getString("context.icon")) |v| seg.icon = v;
    if (table.getString("context.prefix")) |v| seg.prefix = v;
    if (table.getString("context.suffix")) |v| seg.suffix = v;
}

fn parseSegment(table: *const toml.TomlTable, comptime name: []const u8, seg: *SegmentConfig) void {
    if (table.getBool(name ++ ".enabled")) |v| seg.enabled = v;
    if (table.getString(name ++ ".color")) |v| seg.color = Color.fromString(v);
    if (table.getString(name ++ ".icon")) |v| seg.icon = v;
}

test {
    _ = @import("../tests/config_test.zig");
}
