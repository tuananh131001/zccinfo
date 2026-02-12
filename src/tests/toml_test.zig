const std = @import("std");
const toml = @import("../features/toml.zig");

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "empty content" {
    const table = try toml.parse("");
    try expectEqual(@as(usize, 0), table.len);
}

test "comment-only content" {
    const table = try toml.parse("# this is a comment\n# another comment\n");
    try expectEqual(@as(usize, 0), table.len);
}

test "single key=value bare string" {
    const table = try toml.parse("format = hello\n");
    try expectEqual(@as(usize, 1), table.len);
    try expectEqualStrings("format", table.entries[0].key);
    try expectEqualStrings("hello", table.getString("format").?);
}

test "single key=value quoted string" {
    const table = try toml.parse(
        \\format = "{context} | {git}"
        \\
    );
    try expectEqual(@as(usize, 1), table.len);
    try expectEqualStrings("{context} | {git}", table.getString("format").?);
}

test "boolean true" {
    const table = try toml.parse("enabled = true\n");
    try expectEqual(true, table.getBool("enabled").?);
}

test "boolean false" {
    const table = try toml.parse("enabled = false\n");
    try expectEqual(false, table.getBool("enabled").?);
}

test "section-qualified keys" {
    const input =
        \\[context]
        \\color = "yellow"
        \\enabled = true
        \\
    ;
    const table = try toml.parse(input);
    try expectEqual(@as(usize, 2), table.len);
    try expectEqualStrings("yellow", table.getString("context.color").?);
    try expectEqual(true, table.getBool("context.enabled").?);
}

test "multiple sections" {
    const input =
        \\[context]
        \\color = "yellow"
        \\
        \\[git]
        \\color = "magenta"
        \\enabled = false
        \\
    ;
    const table = try toml.parse(input);
    try expectEqual(@as(usize, 3), table.len);
    try expectEqualStrings("yellow", table.getString("context.color").?);
    try expectEqualStrings("magenta", table.getString("git.color").?);
    try expectEqual(false, table.getBool("git.enabled").?);
}

test "top-level and section keys" {
    const input =
        \\format = "{context} | {git}"
        \\
        \\[context]
        \\color = "yellow"
        \\
    ;
    const table = try toml.parse(input);
    try expectEqual(@as(usize, 2), table.len);
    // Top-level key has no section prefix
    try expectEqualStrings("{context} | {git}", table.getString("format").?);
    try expectEqualStrings("yellow", table.getString("context.color").?);
}

test "whitespace handling around equals" {
    const table = try toml.parse("  color  =  \"yellow\"  \n");
    try expectEqualStrings("yellow", table.getString("color").?);
}

test "whitespace handling around section header" {
    const input =
        \\[ context ]
        \\color = "yellow"
        \\
    ;
    const table = try toml.parse(input);
    try expectEqualStrings("yellow", table.getString("context.color").?);
}

test "inline comment" {
    const table = try toml.parse("color = yellow # this is yellow\n");
    try expectEqualStrings("yellow", table.getString("color").?);
}

test "inline comment with quoted string" {
    const table = try toml.parse(
        \\icon = "🤖" # robot emoji
        \\
    );
    try expectEqualStrings("🤖", table.getString("icon").?);
}

test "empty lines between entries" {
    const input =
        \\key1 = value1
        \\
        \\
        \\key2 = value2
        \\
    ;
    const table = try toml.parse(input);
    try expectEqual(@as(usize, 2), table.len);
    try expectEqualStrings("value1", table.getString("key1").?);
    try expectEqualStrings("value2", table.getString("key2").?);
}

test "malformed line without equals is skipped" {
    const input =
        \\this has no equals
        \\key = value
        \\
    ;
    const table = try toml.parse(input);
    try expectEqual(@as(usize, 1), table.len);
    try expectEqualStrings("value", table.getString("key").?);
}

test "empty quoted string" {
    const table = try toml.parse(
        \\icon = ""
        \\
    );
    try expectEqualStrings("", table.getString("icon").?);
}

test "get returns null for missing key" {
    const table = try toml.parse("key = value\n");
    try expectEqual(@as(?[]const u8, null), table.getString("missing"));
}

test "getBool returns null for string value" {
    const table = try toml.parse("key = value\n");
    try expectEqual(@as(?bool, null), table.getBool("key"));
}

test "getString returns null for boolean value" {
    const table = try toml.parse("key = true\n");
    try expectEqual(@as(?[]const u8, null), table.getString("key"));
}

test "content without trailing newline" {
    const table = try toml.parse("key = value");
    try expectEqualStrings("value", table.getString("key").?);
}

test "windows-style line endings (CRLF)" {
    const table = try toml.parse("[section]\r\nkey = value\r\n");
    try expectEqualStrings("value", table.getString("section.key").?);
}
