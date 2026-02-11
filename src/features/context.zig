const model_module = @import("model.zig");

pub const ContextWindow = struct {
    used_percentage: ?f64 = null,
};

pub const StatusInput = struct {
    model: ?model_module.Model = null,
    transcript_path: ?[]const u8 = null,
    cwd: ?[]const u8 = null,
    version: ?[]const u8 = null,
    context_window: ?ContextWindow = null,
};
