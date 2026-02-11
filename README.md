# zccinfo

## Overview

A blazing-fast alternative to JavaScript/Bun-based Claude Code status line tools. Written in Zig for minimal startup time and zero runtime dependencies.

<img width="952" height="342" alt="96868" src="https://github.com/user-attachments/assets/fa1b1214-3365-4f23-ac8c-4853e06e462a" />

## Installation

### Quick Install (Recommended)

1. Install the latest release with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/tuananh131001/zccinfo/main/install.sh | sh
```


2. Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.local/bin/zccinfo"
  }
}
```

Restart Claude Code and you'll see `Ctx: XX%` in the status line when switching between modes.

### Note:

To install to a custom location:

```bash
INSTALL_DIR=/usr/local/bin curl -sSL https://raw.githubusercontent.com/tuananh131001/zccinfo/main/install.sh | sh
```

### Manual Download

Download the appropriate binary from [GitHub Releases](https://github.com/tuananh131001/zccinfo/releases)

### Build from Source

**Prerequisites**: [Zig](https://ziglang.org/) 0.15.2 or later

```bash
# Clone the repository
git clone https://github.com/tuananh131001/zccinfo.git
cd zccinfo

# Build the project
zig build

# The binary is at zig-out/bin/zccinfo

# Or build optimized release binaries for all platforms
zig build release
```

### NixOS / Nix

For NixOS/Home Manager flake configs, add the overlay:

```nix
{
  inputs.zccinfo.url = "github:tuananh131001/zccinfo";

  # In your nixosConfiguration or homeManagerConfiguration:
  nixpkgs.overlays = [ zccinfo.overlays.default ];
  # Then add to packages:
  environment.systemPackages = [ pkgs.zccinfo ];
}
```

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "statusLine": {
    "type": "command",
    "command": "zccinfo"
  }
}
```


## Roadmap

- [ ] Config system (TOML)
- [ ] Auto-wrap
- [ ] Windows support
- [ ] Cost/token tracking
- [ ] Catppuccin theme & TokyoNight theme
- [ ] Multiline support
- [ ] [More...](https://github.com/tuananh131001/zccinfo/projects)

# Development and Misc

For development with `nix develop` or `direnv allow`, see [development guide](docs/development.md).

See [detailed benchmark results](docs/benchmarks.md) for startup time, JSONL parsing, git branch detection, and binary size comparisons.

