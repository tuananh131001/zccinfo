# zccinfo

A Zig CLI tool that calculates Claude Code context usage percentage by parsing JSONL transcript files.

## Overview

This tool reads JSON input from stdin containing the transcript path and model info, then outputs the context usage as a colored percentage status line.

**Input**: JSON via stdin with `model.id` and `transcript_path`

**Output**: Colored status line showing context percentage (e.g., `Ctx: 45.2%`)

## Features

- Parses JSONL transcript files to extract token usage from the most recent entry
- Supports multiple Claude models:
  - 200K tokens (default for most models)
  - 1M tokens for Claude Sonnet 4.5 with `[1m]` suffix
- Colored terminal output
- Filters out sidechain messages and API errors
- Smart timestamp tracking for finding the most recent entry

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

**Prerequisites**: [Zig](https://ziglang.org/) 0.14.0 or later

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
