# Benchmark Results

## 1. Startup Time (Cold Start)

Using small.jsonl (~1MB)

| Tool | Mean (ms) | Std Dev (ms) | Speedup |
|------|-----------|--------------|---------|
| zccinfo (Zig) | 10.56 | 16.33 | baseline |
| ccstatusline (JS) | 143.35 | 14.77 | 13.6x slower |

## 2. JSONL Parsing Performance

| File Size | zccinfo (ms) | ccstatusline (ms) | Speedup |
|-----------|--------------|-------------------|---------|
| small (~1MB) | 8.19 | 150.49 | 18.4x |
| medium (~10MB) | 76.95 | 157.82 | 2.1x |
| large (~100MB) | 846.25 | 216.16 | 0.3x |

## 3. Git Branch Detection

| Tool | Mean (ms) | Approach |
|------|-----------|----------|
| zccinfo | 11.15 | Direct file read of .git/HEAD |
| ccstatusline | 150.65 | execSync('git branch') |

**Speedup**: zccinfo is 13.5x faster

## 4. Binary/Bundle Size

| Tool | Size | Notes |
|------|------|-------|
| zccinfo | ~100KB | Native Zig binary (ReleaseSmall) |
| ccstatusline | ~1MB+ | Bundled JS (requires Bun/Node runtime) |
