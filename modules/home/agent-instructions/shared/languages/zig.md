## Zig

Follow TigerBeetle's TigerStyle. Priority order: safety, performance, developer experience.

### Safety and control flow

- Keep control flow explicit. Bound every loop and queue with a fixed upper limit. Use iteration instead of recursion. Assert non-termination on event loops.
- Allocate all memory statically at startup. Keep memory fixed after initialization with no dynamic allocation, free, or reallocation calls.
- Use explicitly sized integer types (`u32`, `u64`). Reserve architecture-sized `usize` for slice indexing boundaries.
- Cap functions at 70 lines. Push `if` and `switch` up into the parent function and `for` down into pure leaf helpers. Keep state mutations in the parent.
- Split compound booleans into nested `if`/`else` branches and `else if` chains into `else { if (...) {} }` trees. State invariants positively (`if (index < count)`).
- Pass library options explicitly at the call site (`@prefetch(a, .{ .cache = .data, .rw = .read, .locality = 3 })`).
- Pace external events by batching work at the program's own rate rather than acting directly inside callbacks.
- Treat all compiler warnings as errors. Handle every operating error explicitly. Reserve assertions for programmer errors, where corrupt state crashes immediately.

### Assertions

- Write at least two assertions per function. Check arguments, return values, preconditions, postconditions, and invariants across both positive (valid) and negative (invalid) spaces.
- Pair assertions across boundaries, such as before writing to disk and immediately after reading back.
- Split compound assertions into separate calls (`assert(a); assert(b);`).
- Express implications with a single-line `if` (`if (a) assert(b);`).
- Assert compile-time constant relationships and type sizes in `comptime` blocks.

### Memory and cache invalidation

- Pass arguments larger than 16 bytes as `*const T` when the callee reads without copying.
- Initialize large or immovable structs in-place via an out-pointer (`fn init(target: *LargeStruct) !void`) for pointer stability and bounded stack usage. When a field initializes in-place, initialize its container struct in-place too.
- Declare variables at the smallest scope right before use. Keep a single source of state without duplicate variables or aliases.
- Use the lowest-dimensional return type that fits the call site (`void` > `bool` > `u64` > `?u64` > `!u64`).
- Run functions to completion without suspending so precondition assertions hold across the whole body.
- Zero all struct and buffer padding to prevent buffer bleeds and preserve determinism.
- Put a blank line before resource allocation and after its paired `defer`.

### Performance

- Sketch network, disk, memory, and CPU bandwidth and latency before coding. Optimize the slowest resource first after weighting for usage frequency.
- Separate the control plane from the data plane through batching.
- Extract hot loops into standalone functions with primitive arguments and no `self` parameter so the compiler keeps fields in registers.

### Naming, types, and formatting

- Use `snake_case` for functions, variables, and all file names (struct files included). Capitalize acronyms (`VSRState`).
- Write full words in identifiers (except primitive integer indices in math or sort routines) and long flags (`--force`) in scripts.
- Put units and qualifiers at the end of variable names in descending significance (`latency_ms_max`, `latency_ms_min`).
- Choose equal-length counterpart names (`source`/`target`, `source_offset`/`target_offset`) so related expressions align.
- Prefix private helpers and callbacks with their caller's name (`read_sector`, `read_sector_callback`), and put callbacks last in parameter lists.
- Order files top-down with `main` first. Order structs with fields first, types second (ending with `const Self = @This();`), and methods third.
- Pass unique singleton dependencies (`gpa: Allocator`, `time: Time`) positionally from most general to most specific. Pass an `options: struct` when parameters share a primitive type (such as two `u64` arguments) or accept `null`.
- Treat `index` (0-based), `count` (1-based), and `size` (`count * unit`) as distinct domains and convert between them explicitly.
- State integer division rounding with `@divExact`, `@divFloor`, or `div_ceil`.
- Format with `zig fmt`: 4-space indentation, 100-column hard line limit (use trailing commas to wrap), and braces on every multi-line `if`.
- Use only the Zig toolchain with zero external dependencies. Write repository scripts as `scripts/*.zig`.
