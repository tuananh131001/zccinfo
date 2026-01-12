const std = @import("std");

/// Model information parsed from Claude Code's JSON input
pub const Model = struct {
    id: ?[]const u8 = null,
    display_name: ?[]const u8 = null,
};

/// Extracts version number from a Claude model ID.
/// Examples:
///   "claude-opus-4-5-20251101" → "4.5"
///   "claude-sonnet-4-20250514" → "4"
///   "claude-haiku-3-5-20241022" → "3.5"
///   "claude-3-5-sonnet-20241022" → "3.5"
pub fn extractVersion(model_id: []const u8) ?[]const u8 {
    // Known model patterns:
    // New format: claude-{model}-{major}-{minor?}-{date}
    // Old format: claude-{major}-{minor?}-{model}-{date}

    // Try to find version numbers in the model ID
    // Look for patterns like "-4-5-" or "-3-5-" or just "-4-"

    var i: usize = 0;
    while (i < model_id.len) : (i += 1) {
        // Look for a dash followed by a digit
        if (model_id[i] == '-' and i + 1 < model_id.len and std.ascii.isDigit(model_id[i + 1])) {
            const start = i + 1;

            // Find end of first number
            var end = start;
            while (end < model_id.len and std.ascii.isDigit(model_id[end])) : (end += 1) {}

            const major_len = end - start;

            // Skip if major number is too long (likely a date)
            if (major_len > 2) continue;

            // Check if this is followed by -digit pattern (potential minor version)
            if (end < model_id.len - 1 and model_id[end] == '-' and std.ascii.isDigit(model_id[end + 1])) {
                const minor_start = end + 1;
                var minor_end = minor_start;
                while (minor_end < model_id.len and std.ascii.isDigit(model_id[minor_end])) : (minor_end += 1) {}

                const minor_len = minor_end - minor_start;

                // If minor is 1-2 digits, it's a version like "4-5" or "3-5"
                if (minor_len <= 2) {
                    return model_id[start..minor_end];
                }

                // If minor is 8 digits, it's a date - return just major version
                if (minor_len == 8) {
                    return model_id[start..end];
                }
            }

            // Check if followed by dash and non-digit (end of version)
            if (end < model_id.len and model_id[end] == '-') {
                // Check if remaining part looks like a date (8 digits) or model name
                const remaining = model_id[end + 1 ..];
                if (remaining.len >= 8) {
                    // Count leading digits
                    var digit_count: usize = 0;
                    for (remaining) |c| {
                        if (std.ascii.isDigit(c)) {
                            digit_count += 1;
                        } else {
                            break;
                        }
                    }
                    // If exactly 8 leading digits, it's a date - return major version
                    if (digit_count == 8) {
                        return model_id[start..end];
                    }
                }
            }
        }
    }

    return null;
}

/// Checks if display_name already contains a version (ends with digit pattern)
fn displayNameHasVersion(display_name: []const u8) bool {
    if (display_name.len == 0) return false;

    // Check if the last character is a digit
    const last_char = display_name[display_name.len - 1];
    return std.ascii.isDigit(last_char);
}

/// Formats the model display string combining display_name and version.
/// Example: display_name="Opus", version="4.5" → "Opus 4.5"
/// If display_name already has version (e.g., "Opus 4.5"), returns as-is.
pub fn formatDisplayString(buf: []u8, model: Model) ?[]const u8 {
    const display_name = model.display_name orelse return null;

    // If display_name already contains a version, use it directly
    if (displayNameHasVersion(display_name)) {
        return std.fmt.bufPrint(buf, "{s}", .{display_name}) catch null;
    }

    // Extract version from model ID if available
    const version = if (model.id) |id| extractVersion(id) else null;

    if (version) |ver| {
        // Format version: replace "-" with "." (e.g., "4-5" → "4.5")
        var formatted_version: [16]u8 = undefined;
        var ver_len: usize = 0;
        for (ver) |c| {
            if (ver_len >= formatted_version.len) break;
            formatted_version[ver_len] = if (c == '-') '.' else c;
            ver_len += 1;
        }

        return std.fmt.bufPrint(buf, "{s} {s}", .{ display_name, formatted_version[0..ver_len] }) catch null;
    }

    return std.fmt.bufPrint(buf, "{s}", .{display_name}) catch null;
}

test {
    _ = @import("model_test.zig");
}
