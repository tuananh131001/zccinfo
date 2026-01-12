# zig-context-remaining

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

**Prerequisites**: [Zig](https://ziglang.org/) compiler

```bash
# Build the project
zig build

# Run the application
zig build run

# Run unit tests
zig build test
```
