---
name: macos-app-bundle-size-optimization
description: "Minimizing macOS app bundle (.app) and disk image (.dmg) sizes using Mach-O symbol stripping, lossless icns optimization, LZMA ULMO compression, and zero-allocation Swift patterns"
---

# macOS App Bundle Size & Latency Optimization Guide

## 1. Binary Size Stripping (`strip -u -r`)
When building release binaries with Swift Package Manager (`swift build -c release`), the resulting executable retains local debug strings and symbol tables in `__LINKEDIT`.
- Run `strip -u -r "$CONTENTS/MacOS/<Executable>"` before `codesign`.
- This removes all non-dynamic symbol tables while preserving dynamic loader imports and entry points (`_main`), typically shrinking the binary by 2–4 MB.
- Codesign with `codesign --force --sign - "$APP_DIR"` and verify with `codesign --verify --deep --strict "$APP_DIR"`.

## 2. Lossless Application Icon Optimization (`.icns`)
By default, `sips` + `iconutil` embeds uncompressed 32-bit RGBA PNG scanlines across 10 iconset sizes (16x16 to 1024x1024), inflating `.icns` files to 1.5–2.0 MB.
- Run `oxipng -o max -a --strip safe` across all 10 iconset PNGs.
- Assemble `.icns` directly with Apple Ostypes (`ic04` 16x16, `ic11` 16x16@2x, `ic05` 32x32, `ic12` 32x32@2x, `ic07` 128x128, `ic13` 128x128@2x, `ic08` 256x256, `ic14` 256x256@2x, `ic09` 512x512, `ic10` 512x512@2x).
- Format: `b'icns'` + `uint32_be(total_len)` + `[Ostype + uint32_be(chunk_len) + png_bytes]...`.
- Reduces `.icns` file size by 70–75% (e.g. 1.7 MB down to ~450 KB) with 100% zero color degradation or visual loss.

## 3. High-Compression Disk Images (`ULMO` / LZMA)
Instead of legacy `UDZO` (zlib/deflate):
```sh
hdiutil create \
    -volname "App" \
    -srcfolder "$STAGING_DIR" \
    -format ULMO \
    -ov \
    "$OUTPUT_PATH"
```
`ULMO` uses LZMA compression and is supported natively on macOS 10.15+ and macOS 14+, reducing `.dmg` file size by >50% compared to `UDZO`.

## 4. Sub-10µs Local Search Architecture
- **64-bit Character Bloom Mask:** Precompute `UInt64` character bitmasks for all catalog items. A single bitwise check (`candidate.mask & query.mask == query.mask`) rejects ~95% of non-matching items in <1 nanosecond before any fuzzy/string algorithm runs.
- **ASCII Byte Slices:** Pre-cache `[UInt8]` for ASCII candidates and query bytes to bypass Swift Unicode grapheme cluster overhead (`FuzzyMatcher.scoreASCII`).
- **Stack-Allocated Matrix:** Use `withUnsafeTemporaryAllocation` for dynamic programming distance calculations (e.g. Damerau-Levenshtein) to eliminate heap allocations (`[[Int]]`) on search hot paths.
