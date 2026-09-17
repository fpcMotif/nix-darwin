---
name: macos-rust-dyld-linkedit-fix
description: "Diagnose and fix 'mis-aligned LINKEDIT string pool' dyld dlopen errors during Rust cargo builds and installs on macOS Darwin 27+"
---

# macOS Rust dyld 'mis-aligned LINKEDIT string pool' Diagnosis & Fix

## Symptom

During `cargo install` or `cargo build --release` involving procedural macros (such as `sqlx-macros`, `serde_derive`, or `cxx`), compilation fails during `dlopen()`:

```text
error: /path/to/target/release/deps/libfoo_macros-xxxx.dylib: dlopen(...): tried: '...' (mis-aligned LINKEDIT string pool, fileOffset=0x005FB1A4)
```

## Root Cause

1. **macOS Darwin 27+ dyld enforcement**: The dynamic linker strictly validates 8-byte pointer alignment for the Mach-O `__LINKEDIT` symbol table and string pool (`LC_SYMTAB.stroff`).
2. **Cargo release default**: Cargo defaults release builds to `strip = "debuginfo"`.
3. **LLVM Mach-O stripping bug (LLVM #203678)**: `llvm-objcopy --strip-debug` aligns the Mach-O string table to 4 bytes instead of 8 bytes on 64-bit binaries.
4. When `rustc` loads the proc-macro dylib via `dlopen()`, dyld rejects it because `stroff % 8 != 0`.

## Resolution

Disable stripping in Cargo's configuration by creating or appending to `~/.cargo/config.toml`:

```toml
# Workaround for macOS Darwin 27+ dyld alignment enforcement (LLVM issue #203678):
[profile.release]
strip = "none"

[profile.release.build-override]
strip = "none"
```

## Verification

1. Inspect Mach-O load commands on the resulting dylib:
   ```bash
   otool -l <dylib-path> | grep -A 6 "cmd LC_SYMTAB"
   ```
2. Verify that `stroff % 8 == 0` (or `% 16 == 0`).
3. Re-run `cargo build --release` or `cargo install`.
