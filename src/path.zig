const std = @import("std");

/// Returns the last component of a path (the filename or directory name).
/// Handles trailing slashes and various edge cases.
///
/// Examples:
///   "/Users/anh/Projects/zccinfo" -> "zccinfo"
///   "/foo/bar/" -> "bar"
///   "foo" -> "foo"
///   "/" -> "/"
///   "" -> ""
pub fn basename(path: []const u8) []const u8 {
    if (path.len == 0) {
        return path;
    }

    // Trim trailing slashes
    var end = path.len;
    while (end > 0 and path[end - 1] == '/') {
        end -= 1;
    }

    // If entire path was slashes, return "/"
    if (end == 0) {
        return "/";
    }

    // Find the last slash before the trimmed end
    var start: usize = 0;
    var i = end;
    while (i > 0) {
        i -= 1;
        if (path[i] == '/') {
            start = i + 1;
            break;
        }
    }

    return path[start..end];
}

test {
    _ = @import("path_test.zig");
}
