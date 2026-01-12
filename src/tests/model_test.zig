const std = @import("std");
const model = @import("../features/model.zig");

test "extractVersion - new format with minor version" {
    const version = model.extractVersion("claude-opus-4-5-20251101");
    try std.testing.expectEqualStrings("4-5", version.?);
}

test "extractVersion - new format without minor version" {
    const version = model.extractVersion("claude-sonnet-4-20250514");
    try std.testing.expectEqualStrings("4", version.?);
}

test "extractVersion - haiku 3.5" {
    const version = model.extractVersion("claude-haiku-3-5-20241022");
    try std.testing.expectEqualStrings("3-5", version.?);
}

test "extractVersion - old format" {
    const version = model.extractVersion("claude-3-5-sonnet-20241022");
    try std.testing.expectEqualStrings("3-5", version.?);
}

test "formatDisplayString - with version" {
    var buf: [64]u8 = undefined;
    const m = model.Model{ .id = "claude-opus-4-5-20251101", .display_name = "Opus" };
    const result = model.formatDisplayString(&buf, m);
    try std.testing.expectEqualStrings("Opus 4.5", result.?);
}

test "formatDisplayString - without version" {
    var buf: [64]u8 = undefined;
    const m = model.Model{ .id = null, .display_name = "Opus" };
    const result = model.formatDisplayString(&buf, m);
    try std.testing.expectEqualStrings("Opus", result.?);
}

test "formatDisplayString - no display_name" {
    var buf: [64]u8 = undefined;
    const m = model.Model{ .id = "claude-opus-4-5-20251101", .display_name = null };
    const result = model.formatDisplayString(&buf, m);
    try std.testing.expect(result == null);
}

test "formatDisplayString - display_name already has version" {
    var buf: [64]u8 = undefined;
    const m = model.Model{ .id = "claude-opus-4-5-20251101", .display_name = "Opus 4.5" };
    const result = model.formatDisplayString(&buf, m);
    try std.testing.expectEqualStrings("Opus 4.5", result.?);
}
