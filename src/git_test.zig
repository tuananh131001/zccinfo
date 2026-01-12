const std = @import("std");
const git = @import("git.zig");
const testing = std.testing;

test "parseGitHead extracts branch from ref" {
    const content = "ref: refs/heads/main\n";
    const branch = git.parseGitHead(content);
    try testing.expectEqualStrings("main", branch.?);
}

test "parseGitHead handles feature branches with slashes" {
    const content = "ref: refs/heads/feature/my-feature\n";
    const branch = git.parseGitHead(content);
    try testing.expectEqualStrings("feature/my-feature", branch.?);
}

test "parseGitHead handles branch without trailing newline" {
    const content = "ref: refs/heads/develop";
    const branch = git.parseGitHead(content);
    try testing.expectEqualStrings("develop", branch.?);
}

test "parseGitHead returns null for detached HEAD (SHA)" {
    const content = "a1b2c3d4e5f6789012345678901234567890abcd\n";
    const result = git.parseGitHead(content);
    try testing.expect(result == null);
}

test "parseGitHead returns null for empty content" {
    const content = "";
    const result = git.parseGitHead(content);
    try testing.expect(result == null);
}

test "getShortSha returns first 7 characters" {
    const content = "a1b2c3d4e5f6789012345678901234567890abcd\n";
    const short_sha = git.getShortSha(content);
    try testing.expectEqualStrings("a1b2c3d", short_sha.?);
}

test "getShortSha handles content without newline" {
    const content = "a1b2c3d4e5f6789012345678901234567890abcd";
    const short_sha = git.getShortSha(content);
    try testing.expectEqualStrings("a1b2c3d", short_sha.?);
}

test "getShortSha returns null for content too short" {
    const content = "abc123";
    const result = git.getShortSha(content);
    try testing.expect(result == null);
}
