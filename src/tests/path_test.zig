const std = @import("std");
const path = @import("../features/path.zig");
const testing = std.testing;

test "basename: normal path" {
    try testing.expectEqualStrings("baz", path.basename("/foo/bar/baz"));
}

test "basename: trailing slash" {
    try testing.expectEqualStrings("bar", path.basename("/foo/bar/"));
}

test "basename: multiple trailing slashes" {
    try testing.expectEqualStrings("bar", path.basename("/foo/bar///"));
}

test "basename: single component" {
    try testing.expectEqualStrings("foo", path.basename("foo"));
}

test "basename: root only" {
    try testing.expectEqualStrings("/", path.basename("/"));
}

test "basename: root with multiple slashes" {
    try testing.expectEqualStrings("/", path.basename("///"));
}

test "basename: empty string" {
    try testing.expectEqualStrings("", path.basename(""));
}

test "basename: deep path" {
    try testing.expectEqualStrings("zccinfo", path.basename("/Users/anh/Projects/personal/zccinfo"));
}

test "basename: relative path" {
    try testing.expectEqualStrings("baz", path.basename("foo/bar/baz"));
}
