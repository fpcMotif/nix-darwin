## Rust

- Run Cargo through mbx (the mise tool `mr-boxington`): `mbx build`, `mbx test --workspace`, `mbx clippy --all-targets -- -D warnings`. mbx forwards each command to Cargo and shares compiled work across every checkout.
- Plain `cargo` also runs through mbx in zsh, whose PATH puts mbx's cargo shim first. `mbx COMMAND` works in any shell.
- For a slow build or a cache miss, run `mbx explain`. Check the setup with `mbx doctor`. Run `mbx gc --dry-run` before `mbx gc`.
- In a library, define errors as `thiserror` enums. In an application, use `anyhow` and add `.context(...)` where an error crosses a boundary.
- Outside tests, return an error instead of calling `unwrap`. Use `expect("reason")` only where an invariant guarantees success.
