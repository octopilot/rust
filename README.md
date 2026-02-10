# Rust Buildpack

Cloud Native Buildpack for Rust: builds a **single crate**, a **workspace** (all packages), or one **package** in a workspace (suite-style layout).

## Detection

- Passes if `Cargo.toml` exists at the app root or in `BP_RUST_WORKSPACE_DIR`.

## Build

- Installs Rust (rustup, stable) into a cached layer when not present.
- Runs `cargo build --release` with optional target and package selection.
- Copies the resulting binary to `bin/web` and sets the default `web` process.

## Optional environment variables

Set at build time (e.g. `pack build --env BP_RUST_PACKAGE=myapp_service_impl`):

| Variable | Description | Default |
|----------|-------------|---------|
| `BP_RUST_WORKSPACE_DIR` | Subdirectory containing the workspace `Cargo.toml` (e.g. `microservices`) | `.` |
| `BP_RUST_PACKAGE` | Build only this package (`cargo build -p <name>`). Use for building one binary from a multi-package workspace. | unset |
| `BP_RUST_TARGET` | Rust target triple (e.g. `x86_64-unknown-linux-gnu`, `x86_64-unknown-linux-musl`) | `x86_64-unknown-linux-gnu` |
| `BP_RUST_BINARY_NAME` | Override which binary to run when the crate has multiple binaries or a non-default name | inferred |

## Scenarios

1. **Single crate** — One `Cargo.toml` at app root. No env needed. One binary → `bin/web`.
2. **Workspace** — Root `Cargo.toml` with `[workspace]` and multiple members. Builds all; the first binary (or use `BP_RUST_BINARY_NAME`) becomes `bin/web`. Use a Procfile if you need a different command.
3. **Suite (one service)** — Repo has a workspace under a subdirectory (e.g. `microservices/`) with many packages. Set `BP_RUST_WORKSPACE_DIR=microservices` and `BP_RUST_PACKAGE=<crate_name>` to build and run that single binary.

## Builder integration

Add this buildpack to your builder (e.g. in `builder.toml`):

```toml
[[buildpacks]]
  uri = "path-or-docker-to-rust-buildpack"
  version = "0.0.1"

[[order]]
  [[order.group]]
    id = "octopilot/rust"
    version = "0.0.1"
```

## Design

See [DESIGN.md](DESIGN.md) for host-aware patterns, target handling, and arm7/jemalloc notes.
