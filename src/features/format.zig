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

    while (pos < format.len) {
        if (result.len >= max_tokens) break;

        // Look for next '{'
        if (std.mem.indexOfScalarPos(u8, format, pos, '{')) |open| {
            // Add literal before the placeholder (if any)
            if (open > pos) {
                if (result.len >= max_tokens) break;
                result.tokens[result.len] = .{ .literal = format[pos..open] };
                result.len += 1;
            }

            // Find closing '}'
            if (std.mem.indexOfScalarPos(u8, format, open + 1, '}')) |close| {
                if (result.len >= max_tokens) break;
                result.tokens[result.len] = .{ .placeholder = format[open + 1 .. close] };
                result.len += 1;
                pos = close + 1;
            } else {
                // No closing brace — treat rest as literal
                if (result.len >= max_tokens) break;
                result.tokens[result.len] = .{ .literal = format[pos..] };
                result.len += 1;
                break;
            }
        } else {
            // No more placeholders — rest is literal
            if (result.len >= max_tokens) break;
            result.tokens[result.len] = .{ .literal = format[pos..] };
            result.len += 1;
            break;
        }
    }

    return result;
}

/// Render a format string with segment values, collapsing separators
/// when segments are absent.
///
/// Collapsing logic: when a placeholder resolves to null (segment disabled/absent),
/// the adjacent literal (separator) is also removed to avoid " |  | " gaps.
/// Specifically: the literal *before* a null placeholder is removed if there was
/// a previous non-null segment, and the literal *after* is also consumed.
pub fn render(buf: []u8, tokens: *const TokenList, values: *const SegmentValues) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const writer = fbs.writer();

    // First pass: determine which placeholders are present
    // Then render with separator collapsing

    // Collect resolved tokens: for each token, mark if placeholder is present
    var resolved: [max_tokens]?[]const u8 = .{null} ** max_tokens;
    for (tokens.tokens[0..tokens.len], 0..) |token, i| {
        switch (token) {
            .placeholder => |name| {
                if (Segment.fromString(name)) |seg| {
                    resolved[i] = values.getBySegment(seg);
                }
            },
            .literal => {},
        }
    }

    // Find indices of present (non-null) placeholders
    var first_present: ?usize = null;
    var last_present: ?usize = null;
    for (tokens.tokens[0..tokens.len], 0..) |token, i| {
        switch (token) {
            .placeholder => {
                if (resolved[i] != null) {
                    if (first_present == null) first_present = i;
                    last_present = i;
                }
            },
            .literal => {},
        }
    }

    // If no segments are present, output nothing
    if (first_present == null) return fbs.getWritten();

    // Render with collapsing
    var i: usize = 0;
    var prev_was_present_placeholder = false;

    while (i < tokens.len) {
        const token = tokens.tokens[i];
        switch (token) {
            .placeholder => |name| {
                if (resolved[i]) |value| {
                    _ = name;
                    writer.writeAll(value) catch return fbs.getWritten();
                    prev_was_present_placeholder = true;
                } else {
                    // Null placeholder — skip it and handle separator collapsing
                    // If next token is a literal (separator), skip it too
                    if (i + 1 < tokens.len) {
                        switch (tokens.tokens[i + 1]) {
                            .literal => {
                                i += 1; // skip the separator after null placeholder
                            },
                            .placeholder => {},
                        }
                    }
                    prev_was_present_placeholder = false;
                }
            },
            .literal => |text| {
                // Check if the next token is a null placeholder
                if (i + 1 < tokens.len) {
                    switch (tokens.tokens[i + 1]) {
                        .placeholder => {
                            if (resolved[i + 1] == null) {
                                // Next placeholder is null — skip this literal (separator)
                                i += 1;
                                continue;
                            }
                        },
                        .literal => {},
                    }
                }

                // Only write literal if we have context (between present segments)
                if (prev_was_present_placeholder or i < (first_present orelse 0)) {
                    writer.writeAll(text) catch return fbs.getWritten();
                }
            },
        }
        i += 1;
    }

    return fbs.getWritten();
}

test {
    _ = @import("../tests/format_test.zig");
}
