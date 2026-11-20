## JavaScript and TypeScript

- Run scripts with `bun` and executables with `bunx`.
- Use `pnpm` when the repository requires it.
- Type-check TypeScript with `bun check`, Bun's native checker. It replaces `tsc --noEmit` and reads the nearest `tsconfig.json`.
- Scope a check with `bun check -p apps/web` for one package, or `bun check FILE` for a file and its imports.
- Where a script or CI step must run TypeScript's own compiler, use `tsrs`, the Rust port of TypeScript 7.1, in place of `tsc`. It takes the same flags.
- The TypeScript language server is `tsrs --lsp --stdio`.
- Format code with `bun fmt`, or check formatting with `bun fmt --check`. It replaces `oxfmt` and `prettier`, and reads `.oxfmtrc.json` natively.
- Lint with `bun lint`. It replaces `eslint`, and runs most ESLint rules natively.
- Use `oxlint --type-aware` for type-aware linting.
- Confirm a dependency and lockfile before adding a library.
- Use named exports. Use a default export only where a framework requires one.
- Type untrusted input as `unknown` and narrow it with a runtime check. That check replaces `any` and the non-null `!`.
- Await, return, or explicitly handle every promise.
- In React, compute values from props and state during render. Use an effect only to sync with a system outside React.
- Start independent requests together with `Promise.all`.
