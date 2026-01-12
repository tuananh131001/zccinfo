# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## MCP

Use context7 to get latest docs of Zig programming language - libraryId: "/websites/ziglang_0_15_2"

## Build Commands

```bash
# Build the project
zig build

# Run the application
zig build run

# Run unit tests
zig build test
```

## Project Overview

A Zig CLI tool that calculates Claude Code context usage percentage by parsing JSONL transcript files. It reads JSON input from stdin containing the transcript path and model info, then outputs the context usage as a percentage.

**Input**: JSON via stdin with `model.id` and `transcript_path`
**Output**: Colored status line showing context percentage (e.g., `Ctx: 45.2%`)

## Architecture

- `src/main.zig` - Single-file application containing all logic:
  - Reads JSON input from stdin (`StatusInput` struct)
  - Parses JSONL transcript files to extract token usage from most recent entry
  - Determines max context based on model (200K default, 1M for Sonnet 4.5 with `[1m]` suffix)
  - Outputs colored percentage to stdout

## Key Data Structures

- `StatusInput` - Parsed from stdin: contains `model.id` and `transcript_path`
- `TranscriptLine` - JSONL line format with `message.usage` token counts
- `TokenUsage` - Token metrics: `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`
