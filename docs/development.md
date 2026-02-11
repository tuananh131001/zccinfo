# Development

## Prerequisites

- [Zig](https://ziglang.org/) 0.15.2 or later

## Build from Source

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

## Development Commands

```bash
# Run the application
zig build run

# Run unit tests
zig build test
```

## Nix Development

```bash
nix develop        # enter dev shell with Zig 0.15.2
direnv allow       # or auto-activate via .envrc
```
