## Go

- Format changed files with `gofumpt -w`. Lint with `golangci-lint run ./...` and test with `go test ./...`.
- Pass `context.Context` as the first parameter of a function that does I/O or can block.
- Wrap a returned error with what failed: `fmt.Errorf("load config: %w", err)`.
- Write synchronous functions and let the caller start goroutines. Give each goroutine a stop condition that its caller controls.
