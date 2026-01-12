const std = @import("std");
const main = @import("main.zig");

test "getContextConfig returns 1M for sonnet 4.5 with [1m] suffix" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = main.getContextConfig(allocator, "claude-sonnet-4-5-20250929[1m]");
    try std.testing.expectEqual(@as(u64, 1_000_000), config.max_tokens);
}

test "getContextConfig returns 1M for uppercase [1M] suffix" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = main.getContextConfig(allocator, "claude-sonnet-4-5-20250929[1M]");
    try std.testing.expectEqual(@as(u64, 1_000_000), config.max_tokens);
}

test "getContextConfig returns 200k for sonnet 4.5 without suffix" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = main.getContextConfig(allocator, "claude-sonnet-4-5-20250929");
    try std.testing.expectEqual(@as(u64, 200_000), config.max_tokens);
}

test "getContextConfig returns 200k for older models" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = main.getContextConfig(allocator, "claude-3-5-sonnet-20241022");
    try std.testing.expectEqual(@as(u64, 200_000), config.max_tokens);
}

test "getContextConfig returns 200k for null model_id" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = main.getContextConfig(allocator, null);
    try std.testing.expectEqual(@as(u64, 200_000), config.max_tokens);
}

test "timestampGreater compares ISO timestamps correctly" {
    try std.testing.expect(main.timestampGreater("2025-01-12T10:05:00Z", "2025-01-12T10:00:00Z"));
    try std.testing.expect(!main.timestampGreater("2025-01-12T10:00:00Z", "2025-01-12T10:05:00Z"));
    try std.testing.expect(!main.timestampGreater("2025-01-12T10:00:00Z", "2025-01-12T10:00:00Z"));
}
