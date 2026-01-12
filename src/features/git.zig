const std = @import("std");

/// Result of git branch detection
pub const GitStatus = struct {
    branch: ?[]const u8,
    is_detached: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GitStatus) void {
        if (self.branch) |b| self.allocator.free(b);
    }
};

/// Parse .git/HEAD content to extract branch name
/// Returns the branch name if it's a ref, null if detached HEAD
pub fn parseGitHead(content: []const u8) ?[]const u8 {
    const prefix = "ref: refs/heads/";
    if (std.mem.startsWith(u8, content, prefix)) {
        const rest = content[prefix.len..];
        return std.mem.trimRight(u8, rest, "\n\r");
    }
    return null;
}

/// Get the short SHA for detached HEAD state
pub fn getShortSha(content: []const u8) ?[]const u8 {
    const trimmed = std.mem.trimRight(u8, content, "\n\r");
    // SHA should be at least 7 chars for short form
    if (trimmed.len >= 7) {
        return trimmed[0..7];
    }
    return null;
}

/// Find .git directory by walking up from current working directory
fn findGitDir(allocator: std.mem.Allocator) ?[]const u8 {
    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.fs.cwd().realpath(".", &cwd_buf) catch return null;

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var current_path: []const u8 = cwd;

    while (true) {
        // Try to open .git/HEAD in current directory
        const git_head_path = std.fmt.bufPrint(&path_buf, "{s}/.git/HEAD", .{current_path}) catch return null;

        if (std.fs.cwd().access(git_head_path, .{})) |_| {
            // Found .git/HEAD, return .git directory path
            const git_dir = std.fmt.bufPrint(&path_buf, "{s}/.git", .{current_path}) catch return null;
            return allocator.dupe(u8, git_dir) catch return null;
        } else |_| {
            // Not found, try parent directory
        }

        // Go up one directory
        const parent_end = std.mem.lastIndexOfScalar(u8, current_path, '/') orelse return null;
        if (parent_end == 0) {
            // Reached root
            return null;
        }
        current_path = current_path[0..parent_end];
    }
}

/// Get current git branch by reading .git/HEAD
pub fn getCurrentBranch(allocator: std.mem.Allocator) ?GitStatus {
    const git_dir = findGitDir(allocator) orelse return null;
    defer allocator.free(git_dir);

    // Build path to .git/HEAD
    var head_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const head_path = std.fmt.bufPrint(&head_path_buf, "{s}/HEAD", .{git_dir}) catch return null;

    // Read .git/HEAD
    const file = std.fs.cwd().openFile(head_path, .{}) catch return null;
    defer file.close();

    var content_buf: [256]u8 = undefined;
    const bytes_read = file.readAll(&content_buf) catch return null;
    const content = content_buf[0..bytes_read];

    // Try to parse as branch ref
    if (parseGitHead(content)) |branch_name| {
        const branch_copy = allocator.dupe(u8, branch_name) catch return null;
        return GitStatus{
            .branch = branch_copy,
            .is_detached = false,
            .allocator = allocator,
        };
    }

    // Detached HEAD - return short SHA
    if (getShortSha(content)) |short_sha| {
        const sha_copy = allocator.dupe(u8, short_sha) catch return null;
        return GitStatus{
            .branch = sha_copy,
            .is_detached = true,
            .allocator = allocator,
        };
    }

    return null;
}

test {
    _ = @import("../tests/git_test.zig");
}
