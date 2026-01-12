# zccinfo

A fast, lightweight Zig CLI tool that provides an informative status line for Claude Code, displaying context usage and git branch information.

## Overview

A blazing-fast alternative to JavaScript/Bun-based Claude Code status line tools. Written in Zig for minimal startup time and zero runtime dependencies.

## Features

### Status Line
- **Context usage percentage** with colored output (e.g., `Ctx: 45.2%`)
- **Git branch display** with Powerline icon (e.g., ` main`)
- Graceful handling when not in a git repository

### Context Tracking
- Parses JSONL transcript files to extract token usage from the most recent entry
- Supports multiple Claude models:
  - 200K tokens (default for most models)
  - 1M tokens for Claude Sonnet 4.5 with `[1m]` suffix
- Filters out sidechain messages and API errors
- Smart timestamp tracking for finding the most recent entry

### Git Integration
- Detects current branch from `.git/HEAD`
- Shows short SHA (7 chars) in detached HEAD state
- Walks up directories to find git root

## Installation

### Quick Install (Recommended)

Install the latest release with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/tuananh131001/zccinfo/main/install.sh | sh
```

This will:
- Detect your OS (macOS/Linux) and architecture (x86_64/ARM64)
- Download the correct pre-built binary
- Verify the checksum
- Install to `~/.local/bin`

To install to a custom location:

```bash
INSTALL_DIR=/usr/local/bin curl -sSL https://raw.githubusercontent.com/tuananh131001/zccinfo/main/install.sh | sh
```

### Manual Download

Download the appropriate binary from [GitHub Releases](https://github.com/tuananh131001/zccinfo/releases):

| Platform | Archive |
|----------|---------|
| macOS (Apple Silicon) | `zig-context-aarch64-macos.tar.gz` |
| macOS (Intel) | `zig-context-x86_64-macos.tar.gz` |
| Linux (x86_64) | `zig-context-x86_64-linux.tar.gz` |
| Linux (ARM64) | `zig-context-aarch64-linux.tar.gz` |

### Build from Source

**Prerequisites**: [Zig](https://ziglang.org/) 0.15.2 or later

```bash
# Clone the repository
git clone https://github.com/tuananh131001/zccinfo.git
cd zccinfo

# Build the project
zig build

# The binary is at zig-out/bin/zig-context

# Or build optimized release binaries for all platforms
zig build release
```

### Development Commands

```bash
# Run the application
zig build run

# Run unit tests
zig build test
```

## Claude Code Configuration

Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "status_line": {
    "type": "command",
    "command": "~/.local/bin/zig-context"
  }
}
```

Restart Claude Code and you'll see `Ctx: XX%` in the status line.

## Benchmark Results

### 1. Startup Time (Cold Start)

Using small.jsonl (~1MB)

| Tool | Mean (ms) | Std Dev (ms) | Speedup |
|------|-----------|--------------|---------|
| zccinfo (Zig) | 10.56 | 16.33 | baseline |
| ccstatusline (JS) | 143.35 | 14.77 | 13.6x slower |

### 2. JSONL Parsing Performance

| File Size | zccinfo (ms) | ccstatusline (ms) | Speedup |
|-----------|--------------|-------------------|---------|
| small (~1MB) | 8.19 | 150.49 | 18.4x |
| medium (~10MB) | 76.95 | 157.82 | 2.1x |
| large (~100MB) | 846.25 | 216.16 | 0.3x |

### 3. Git Branch Detection

| Tool | Mean (ms) | Approach |
|------|-----------|----------|
| zccinfo | 11.15 | Direct file read of .git/HEAD |
| ccstatusline | 150.65 | execSync('git branch') |

**Speedup**: zccinfo is 13.5x faster

### 4. Binary/Bundle Size

| Tool | Size | Notes |
|------|------|-------|
| zccinfo | ~100KB | Native Zig binary (ReleaseSmall) |
| ccstatusline | ~1MB+ | Bundled JS (requires Bun/Node runtime) |

