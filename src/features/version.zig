const std = @import("std");

/// Icon for version display
pub const version_icon = "\u{1F4E6}"; // 📦 package emoji

/// Formats the Claude Code version for display.
/// Ensures the version has a 'v' prefix.
/// Examples:
///   "2.1.7" → "v2.1.7"
///   "v2.1.7" → "v2.1.7"
///   "" → null
pub fn formatVersion(buf: []u8, version: []const u8) ?[]const u8 {
    if (version.len == 0) return null;

    // If already has 'v' or 'V' prefix, return as-is
    if (version[0] == 'v' or version[0] == 'V') {
        return std.fmt.bufPrint(buf, "{s}", .{version}) catch null;
    }

    // Add 'v' prefix
    return std.fmt.bufPrint(buf, "v{s}", .{version}) catch null;
}

test {
    _ = @import("../tests/version_test.zig");
}
