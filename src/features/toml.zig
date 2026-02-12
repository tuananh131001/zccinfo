const std = @import("std");

/// Maximum number of key-value entries in a TOML table
const max_entries = 64;
/// Maximum length of a qualified key ("section.key")
const max_key_len = 64;

/// A single key-value entry from a TOML file.
/// Keys are stored as "section.key" for entries under a [section] header.
/// All string values point into the original source buffer (zero-copy).
pub const Entry = struct {
    key: []const u8,
    value: Value,
};

/// A parsed TOML value
pub const Value = union(enum) {
    string: []const u8,
    boolean: bool,
};

/// A parsed TOML table with bounded storage.
/// Zero-allocation: all entries stored in a fixed-size array,
/// all string values point into the original source buffer.
/// Qualified keys (section.key) are stored in an internal buffer pool.
pub const TomlTable = struct {
    entries: [max_entries]Entry = undefined,
    len: usize = 0,
    // Internal buffer pool for qualified keys
    key_bufs: [max_entries][max_key_len]u8 = undefined,

    /// Look up a value by fully-qualified key (e.g. "context.color")
    pub fn get(self: *const TomlTable, key: []const u8) ?Value {
        for (self.entries[0..self.len]) |entry| {
            if (std.mem.eql(u8, entry.key, key)) {
                return entry.value;
            }
        }
        return null;
    }

    /// Look up a string value by key, returning null if not found or not a string
    pub fn getString(self: *const TomlTable, key: []const u8) ?[]const u8 {
        const val = self.get(key) orelse return null;
        return switch (val) {
            .string => |s| s,
            .boolean => null,
        };
    }

    /// Look up a boolean value by key, returning null if not found or not a boolean
    pub fn getBool(self: *const TomlTable, key: []const u8) ?bool {
        const val = self.get(key) orelse return null;
        return switch (val) {
            .boolean => |b| b,
            .string => null,
        };
    }
};

/// Parse error types
pub const ParseError = error{
    TooManyEntries,
};

/// Parse a TOML string into a TomlTable.
/// Only supports the subset needed for config: comments, sections, key=value with
/// string (bare or quoted) and boolean values.
pub fn parse(source: []const u8) ParseError!TomlTable {
    var table = TomlTable{};
    var current_section: []const u8 = "";

    var line_start: usize = 0;
    while (line_start < source.len) {
        // Find end of line
        var line_end = line_start;
        while (line_end < source.len and source[line_end] != '\n') : (line_end += 1) {}

        const line = stripTrailingCR(source[line_start..line_end]);
        line_start = line_end + 1;

        const trimmed = trimWhitespace(line);

        // Skip empty lines and comments
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Section header
        if (trimmed[0] == '[') {
            if (parseSectionHeader(trimmed)) |section| {
                current_section = section;
            }
            continue;
        }

        // Key = value
        if (parseKeyValue(trimmed)) |kv| {
            if (table.len >= max_entries) return ParseError.TooManyEntries;

            const qualified = if (current_section.len > 0)
                buildQualifiedKey(&table.key_bufs[table.len], current_section, kv.key)
            else
                kv.key;

            table.entries[table.len] = .{
                .key = qualified,
                .value = kv.value,
            };
            table.len += 1;
        }
    }

    return table;
}

fn buildQualifiedKey(buf: *[max_key_len]u8, section: []const u8, key: []const u8) []const u8 {
    const total_len = section.len + 1 + key.len;
    if (total_len > max_key_len) return key; // fallback
    @memcpy(buf[0..section.len], section);
    buf[section.len] = '.';
    @memcpy(buf[section.len + 1 ..][0..key.len], key);
    return buf[0..total_len];
}

fn parseSectionHeader(line: []const u8) ?[]const u8 {
    const end = std.mem.indexOfScalar(u8, line, ']') orelse return null;
    if (end <= 1) return null;
    return trimWhitespace(line[1..end]);
}

const KeyValue = struct {
    key: []const u8,
    value: Value,
};

fn parseKeyValue(line: []const u8) ?KeyValue {
    const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse return null;
    if (eq_pos == 0) return null;

    const key = trimWhitespace(line[0..eq_pos]);
    if (key.len == 0) return null;

    const raw_value = trimWhitespace(line[eq_pos + 1 ..]);
    if (raw_value.len == 0) return null;

    // Strip inline comments (# after value, but not inside quotes)
    const value_str = stripInlineComment(raw_value);
    if (value_str.len == 0) return null;

    // Boolean values
    if (std.mem.eql(u8, value_str, "true")) {
        return .{ .key = key, .value = .{ .boolean = true } };
    }
    if (std.mem.eql(u8, value_str, "false")) {
        return .{ .key = key, .value = .{ .boolean = false } };
    }

    // Quoted string
    if (value_str.len >= 2 and value_str[0] == '"' and value_str[value_str.len - 1] == '"') {
        return .{ .key = key, .value = .{ .string = value_str[1 .. value_str.len - 1] } };
    }

    // Bare string (unquoted value)
    return .{ .key = key, .value = .{ .string = value_str } };
}

fn stripInlineComment(value: []const u8) []const u8 {
    // If value starts with a quote, find the closing quote first
    if (value.len >= 2 and value[0] == '"') {
        var i: usize = 1;
        while (i < value.len) : (i += 1) {
            if (value[i] == '"') {
                return trimWhitespace(value[0 .. i + 1]);
            }
        }
        return value;
    }

    // For unquoted values, strip everything after #
    if (std.mem.indexOfScalar(u8, value, '#')) |hash_pos| {
        return trimWhitespace(value[0..hash_pos]);
    }
    return value;
}

fn trimWhitespace(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t");
}

fn stripTrailingCR(s: []const u8) []const u8 {
    if (s.len > 0 and s[s.len - 1] == '\r') {
        return s[0 .. s.len - 1];
    }
    return s;
}

test {
    _ = @import("../tests/toml_test.zig");
}
