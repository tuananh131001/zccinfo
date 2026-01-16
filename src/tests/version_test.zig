const std = @import("std");
const version = @import("../features/version.zig");

test "formatVersion - adds v prefix when missing" {
    var buf: [32]u8 = undefined;
    const result = version.formatVersion(&buf, "2.1.7");
    try std.testing.expectEqualStrings("v2.1.7", result.?);
}

test "formatVersion - keeps v prefix when present" {
    var buf: [32]u8 = undefined;
    const result = version.formatVersion(&buf, "v2.1.7");
    try std.testing.expectEqualStrings("v2.1.7", result.?);
}

test "formatVersion - handles uppercase V" {
    var buf: [32]u8 = undefined;
    const result = version.formatVersion(&buf, "V2.1.7");
    try std.testing.expectEqualStrings("V2.1.7", result.?);
}

test "formatVersion - returns null for empty string" {
    var buf: [32]u8 = undefined;
    const result = version.formatVersion(&buf, "");
    try std.testing.expect(result == null);
}

test "version_icon is defined" {
    try std.testing.expect(version.version_icon.len > 0);
}
