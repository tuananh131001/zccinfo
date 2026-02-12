const std = @import("std");

/// Maximum number of tokens from a format string
const max_tokens = 32;

/// A token from parsing a format string
pub const Token = union(enum) {
    literal: []const u8,
    placeholder: []const u8,
};

/// Result of tokenizing a format string
pub const TokenList = struct {
    tokens: [max_tokens]Token = undefined,
    len: usize = 0,
};

/// Segment names that can appear in format strings
pub const Segment = enum {
    context,
    git,
    folder,
    model,
    version,

    pub fn fromString(name: []const u8) ?Segment {
        const map = .{
            .{ "context", .context },
            .{ "git", .git },
            .{ "folder", .folder },
            .{ "model", .model },
            .{ "version", .version },
        };
        inline for (map) |entry| {
            if (std.mem.eql(u8, name, entry[0])) return entry[1];
        }
        return null;
    }
};

/// Values for each segment, null means segment is absent/disabled
pub const SegmentValues = struct {
    context: ?[]const u8 = null,
    git: ?[]const u8 = null,
    folder: ?[]const u8 = null,
    model: ?[]const u8 = null,
    version: ?[]const u8 = null,

    pub fn getBySegment(self: *const SegmentValues, segment: Segment) ?[]const u8 {
        return switch (segment) {
            .context => self.context,
            .git => self.git,
            .folder => self.folder,
            .model => self.model,
            .version => self.version,
        };
    }
};

/// Tokenize a format string into literals and placeholders.
/// Format: "{segment_name}" for placeholders, everything else is literal.
pub fn tokenize(format: []const u8) TokenList {
    var result = TokenList{};
    var pos: usize = 0;

    while (pos < format.len and result.len < max_tokens) {
        // Find next placeholder
        const open_opt = std.mem.indexOfScalarPos(u8, format, pos, '{');

        if (open_opt) |open| {
            // Check for matching close brace
            if (std.mem.indexOfScalarPos(u8, format, open + 1, '}')) |close| {
                // Found a valid placeholder {name}

                // Add literal before placeholder if any
                if (open > pos) {
                    result.tokens[result.len] = .{ .literal = format[pos..open] };
                    result.len += 1;
                    if (result.len >= max_tokens) break;
                }

                // Add placeholder
                result.tokens[result.len] = .{ .placeholder = format[open + 1 .. close] };
                result.len += 1;

                // Advance past closing brace
                pos = close + 1;
                continue;
            }
        }

        // No valid placeholder found, or no closing brace
        // Treat remainder as literal
        result.tokens[result.len] = .{ .literal = format[pos..] };
        result.len += 1;
        break;
    }

    return result;
}

/// Render a format string. Missing placeholders render as "<empty>".
pub fn render(buf: []u8, tokens: *const TokenList, values: *const SegmentValues) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();

    for (tokens.tokens[0..tokens.len]) |token| {
        switch (token) {
            .literal => |text| {
                writer.writeAll(text) catch return fbs.getWritten();
            },
            .placeholder => |name| {
                if (Segment.fromString(name)) |seg| {
                    if (values.getBySegment(seg)) |val| {
                        writer.writeAll(val) catch return fbs.getWritten();
                    } else {
                        writer.writeAll("<empty>") catch return fbs.getWritten();
                    }
                } else {
                    writer.writeAll("<empty>") catch return fbs.getWritten();
                }
            },
        }
    }

    return fbs.getWritten();
}

test {
    _ = @import("../tests/format_test.zig");
}
