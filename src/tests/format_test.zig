const std = @import("std");
const format = @import("../features/format.zig");

const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual = std.testing.expectEqual;

test "tokenize basic format string" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    try expectEqual(@as(usize, 5), tokens.len);
    // placeholder "context"
    try expectEqualStrings("context", tokens.tokens[0].placeholder);
    // literal " | "
    try expectEqualStrings(" | ", tokens.tokens[1].literal);
    // placeholder "git"
    try expectEqualStrings("git", tokens.tokens[2].placeholder);
    // literal " | "
    try expectEqualStrings(" | ", tokens.tokens[3].literal);
    // placeholder "folder"
    try expectEqualStrings("folder", tokens.tokens[4].placeholder);
}

test "tokenize with leading literal" {
    const tokens = format.tokenize("Status: {context}");
    try expectEqual(@as(usize, 2), tokens.len);
    try expectEqualStrings("Status: ", tokens.tokens[0].literal);
    try expectEqualStrings("context", tokens.tokens[1].placeholder);
}

test "tokenize no placeholders" {
    const tokens = format.tokenize("just a literal string");
    try expectEqual(@as(usize, 1), tokens.len);
    try expectEqualStrings("just a literal string", tokens.tokens[0].literal);
}

test "tokenize adjacent placeholders" {
    const tokens = format.tokenize("{context}{git}");
    try expectEqual(@as(usize, 2), tokens.len);
    try expectEqualStrings("context", tokens.tokens[0].placeholder);
    try expectEqualStrings("git", tokens.tokens[1].placeholder);
}

test "render all segments present" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    const values = format.SegmentValues{
        .context = "Ctx: 50.0%",
        .git = "main",
        .folder = "project",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("Ctx: 50.0% | main | project", result);
}

test "render middle segment null" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    const values = format.SegmentValues{
        .context = "Ctx: 50.0%",
        .git = null,
        .folder = "project",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("Ctx: 50.0% | <empty> | project", result);
}

test "render first segment null" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    const values = format.SegmentValues{
        .context = null,
        .git = "main",
        .folder = "project",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("<empty> | main | project", result);
}

test "render last segment null" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    const values = format.SegmentValues{
        .context = "Ctx: 50.0%",
        .git = "main",
        .folder = null,
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("Ctx: 50.0% | main | <empty>", result);
}

test "render all segments null — empty output" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    const values = format.SegmentValues{};
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("<empty> | <empty> | <empty>", result);
}

test "render custom separator" {
    const tokens = format.tokenize("{context} :: {git} :: {folder}");
    const values = format.SegmentValues{
        .context = "Ctx: 50.0%",
        .git = "main",
        .folder = "project",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("Ctx: 50.0% :: main :: project", result);
}

test "render adjacent placeholders both present" {
    const tokens = format.tokenize("{context}{git}");
    const values = format.SegmentValues{
        .context = "A",
        .git = "B",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("AB", result);
}

test "render all five segments" {
    const tokens = format.tokenize("{context} | {git} | {folder} | {model} | {version}");
    const values = format.SegmentValues{
        .context = "Ctx: 50.0%",
        .git = "main",
        .folder = "project",
        .model = "Opus 4.5",
        .version = "v2.1.39",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("Ctx: 50.0% | main | project | Opus 4.5 | v2.1.39", result);
}

test "render multiple middle segments null" {
    const tokens = format.tokenize("{context} | {git} | {folder} | {model} | {version}");
    const values = format.SegmentValues{
        .context = "Ctx: 50.0%",
        .git = null,
        .folder = null,
        .model = null,
        .version = "v2.1.39",
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("Ctx: 50.0% | <empty> | <empty> | <empty> | v2.1.39", result);
}

test "render only one segment present" {
    const tokens = format.tokenize("{context} | {git} | {folder}");
    const values = format.SegmentValues{
        .context = null,
        .git = "main",
        .folder = null,
    };
    var buf: [512]u8 = undefined;
    const result = format.render(&buf, &tokens, &values);
    try expectEqualStrings("<empty> | main | <empty>", result);
}

test "tokenize with unclosed brace (regression test)" {
    const tokens = format.tokenize("foo {bar");
    try expectEqual(@as(usize, 1), tokens.len);
    try expectEqualStrings("foo {bar", tokens.tokens[0].literal);
}
