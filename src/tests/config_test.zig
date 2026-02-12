const std = @import("std");
const toml = @import("toml");
const config_module = @import("../features/config.zig");

const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "default config matches current behavior" {
    const cfg = config_module.default_config;

    // Context segment: yellow, "Ctx: " prefix, "%" suffix
    try expectEqual(true, cfg.context.enabled);
    try expectEqual(config_module.Color.yellow, cfg.context.color);
    try expectEqualStrings("Ctx: ", cfg.context.prefix);
    try expectEqualStrings("%", cfg.context.suffix);

    // Git segment: magenta, powerline icon
    try expectEqual(true, cfg.git.enabled);
    try expectEqual(config_module.Color.magenta, cfg.git.color);
    try expectEqualStrings("\u{e0a0}", cfg.git.icon);

    // Folder segment: magenta, folder icon
    try expectEqual(true, cfg.folder.enabled);
    try expectEqual(config_module.Color.magenta, cfg.folder.color);
    try expectEqualStrings("\u{f07b}", cfg.folder.icon);

    // Model segment: no color, robot emoji
    try expectEqual(true, cfg.model.enabled);
    try expectEqual(config_module.Color.none, cfg.model.color);
    try expectEqualStrings("\u{1F916}", cfg.model.icon);

    // Version segment: no color, package emoji
    try expectEqual(true, cfg.version.enabled);
    try expectEqual(config_module.Color.none, cfg.version.color);
    try expectEqualStrings("\u{1F4E6}", cfg.version.icon);

    // Default format string
    try expectEqualStrings("{context} | {git} | {folder} | {model} | {version}", cfg.getFormat());
}

test "partial config fills defaults" {
    const input =
        \\[context]
        \\color = "red"
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    // Context color overridden
    try expectEqual(config_module.Color.red, cfg.context.color);
    // Context prefix unchanged (default)
    try expectEqualStrings("Ctx: ", cfg.context.prefix);
    // Git unchanged (default)
    try expectEqual(config_module.Color.magenta, cfg.git.color);
}

test "unknown keys ignored" {
    const input =
        \\[context]
        \\unknown_key = "whatever"
        \\color = "green"
        \\
        \\[nonexistent_section]
        \\foo = "bar"
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    // Known key parsed correctly
    try expectEqual(config_module.Color.green, cfg.context.color);
    // Rest stays default
    try expectEqual(true, cfg.context.enabled);
}

test "invalid color falls back to none" {
    const input =
        \\[context]
        \\color = "rainbow"
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    try expectEqual(config_module.Color.none, cfg.context.color);
}

test "enabled = false disables segment" {
    const input =
        \\[git]
        \\enabled = false
        \\
        \\[model]
        \\enabled = false
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    try expectEqual(false, cfg.git.enabled);
    try expectEqual(false, cfg.model.enabled);
    // Others remain enabled
    try expectEqual(true, cfg.context.enabled);
    try expectEqual(true, cfg.folder.enabled);
    try expectEqual(true, cfg.version.enabled);
}

test "custom format string" {
    const input =
        \\format = "{context} :: {git}"
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    try expectEqualStrings("{context} :: {git}", cfg.getFormat());
}

test "custom icons" {
    const input =
        \\[git]
        \\icon = "G:"
        \\
        \\[folder]
        \\icon = "F:"
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    try expectEqualStrings("G:", cfg.git.icon);
    try expectEqualStrings("F:", cfg.folder.icon);
}

test "color toAnsi returns correct codes" {
    try expectEqualStrings("\x1b[33m", config_module.Color.yellow.toAnsi());
    try expectEqualStrings("\x1b[35m", config_module.Color.magenta.toAnsi());
    try expectEqualStrings("", config_module.Color.none.toAnsi());
    try expectEqualStrings("\x1b[31m", config_module.Color.red.toAnsi());
}

test "context prefix and suffix customization" {
    const input =
        \\[context]
        \\prefix = "Context: "
        \\suffix = " pct"
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    try expectEqualStrings("Context: ", cfg.context.prefix);
    try expectEqualStrings(" pct", cfg.context.suffix);
}

test "empty icon string" {
    const input =
        \\[git]
        \\icon = ""
        \\
    ;
    const table = try toml.parse(input);
    const cfg = config_module.parseConfig(&table);

    try expectEqualStrings("", cfg.git.icon);
}
