# Rust Buildpack

Cloud Native Buildpack for Rust: builds a **single crate**, a **workspace** (all packages), or one **package** in a workspace (suite-style layout).

## Detection

- Passes if `Cargo.toml` exists at the app root or in `BP_RUST_WORKSPACE_DIR`.

## Build

- Installs Rust (rustup, stable) into a cached layer when not present.
- Runs `cargo build` in **release** or **debug** mode (see `BP_RUST_BUILD_PROFILE`), with optional target and package selection.
- Copies the resulting binary to `bin/<name>` (name from Cargo: package name or `[[bin]]` name, hyphens → underscores) and sets the default `web` process.

**Asset copy (public/, config/, etc.)**: The buildpack does *not* copy assets. Use `project.toml` with an [inline buildpack](https://buildpacks.io/docs/for-app-developers/how-to/build-inputs/use-inline-buildpacks) to copy `public/`, `config/`, or other app-specific paths after the Rust build. Example:

```toml
[[io.buildpacks.group]]
id = "octopilot/rust"
version = "0.1.3"

[[io.buildpacks.group]]
id = "myapp/copy-assets"
[io.buildpacks.group.script]
api = "0.10"
inline = """
set -e
OUT="${CNB_OUTPUT_DIR:-/workspace}"
APP="${CNB_BUILD_DIR:-/workspace}"
[ -d "$APP/public" ] && cp -r "$APP/public" "$OUT/" || true
"""
```

This keeps the buildpack focused and lets apps define their layout explicitly.

## Optional environment variables

Set at build time (e.g. `pack build --env BP_RUST_PACKAGE=myapp_service_impl` or `pack build --env BP_RUST_BUILD_PROFILE=debug`):

| Variable | Description | Default |
|----------|-------------|---------|
| `BP_RUST_BUILD_PROFILE` | Build profile: `release` (optimized, default) or `debug` (faster compile, larger/slower binary). Accepts `release`, `debug`, or `true`/`false`. | `release` |
| `BP_RUST_WORKSPACE_DIR` | Subdirectory containing the workspace `Cargo.toml` (e.g. `microservices`) | `.` |
| `BP_RUST_PACKAGE` | Build only this package (`cargo build -p <name>`). Use for building one binary from a multi-package workspace. When unset, builds all workspace binaries (monolith mode). | unset |
| `BP_RUST_WORKSPACE_MODE` | `all` = build all binaries into one image (monolith). Default when `BP_RUST_PACKAGE` is unset. | `all` |
| `BP_RUST_FEATURES` | Cargo features to enable (e.g. `dioxus-app-backend/server` for Dioxus fullstack backend). | unset |
| `BP_RUST_TARGET` | Rust target triple (e.g. `x86_64-unknown-linux-gnu`, `x86_64-unknown-linux-musl`). If unset, the buildpack uses the container’s native arch. | native arch |
| `BP_RUST_BINARY_NAME` | Override which binary to run when the crate has multiple binaries or a non-default name | inferred |

## Scenarios

1. **Single crate** — One `Cargo.toml` at app root. No env needed. One binary → `bin/<crate_name>` (e.g. `bin/rust_smoke` for package `rust-smoke`).
2. **Workspace (monolith)** — Root `Cargo.toml` with `[workspace]` and multiple members. Builds all binaries into one image; each gets a process type (`web` for first, `backend`/`frontend` etc. for others). Run with `docker run <image>` (default `web`) or `docker run --entrypoint bin/dioxus-app-backend <image>` for a specific binary. For Dioxus backends that need features, set `BP_RUST_FEATURES=dioxus-app-backend/server`.
3. **Suite (one service)** — Repo has a workspace under a subdirectory (e.g. `microservices/`) with many packages. Set `BP_RUST_WORKSPACE_DIR=microservices` and `BP_RUST_PACKAGE=<crate_name>` to build and run that single binary.
4. **Debug builds** — For faster iteration or debugging, set `BP_RUST_BUILD_PROFILE=debug` (e.g. `pack build myapp --env BP_RUST_BUILD_PROFILE=debug`). Use `release` (default) for production.

## Single-step CI build (with optional per-binary images)

Use `scripts/package.sh` for a single CI step that builds the monolith and optionally creates one image per binary:

```bash
# Monolith only
./scripts/package.sh --build-app --path . --builder my-builder --image myapp

# Monolith + per-binary images (RUST_SPLIT_IMAGES=true or --split-images)
./scripts/package.sh --build-app --path . --builder my-builder --image myapp --split-images
```

With `--split-images`, you get `myapp` (monolith) plus `myapp:dioxus-app-backend`, `myapp:dioxus-app-frontend`, etc. Env vars (e.g. `BP_RUST_FEATURES`) are passed through to pack build.

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

## Troubleshooting

### Finding the binary path in the built image

The buildpack copies the Cargo-built binary to `<OUTPUT_DIR>/bin/<name>` (e.g. `/workspace/bin/rust_smoke` or `/workspace/bin/rust-smoke`). The exact name is whatever Cargo produced (from the package name or `[[bin]]`). If the default process doesn’t run (e.g. “no default process”), run the binary explicitly:

```bash
docker run --rm --entrypoint find <image> / -type f \( -name 'rust_smoke' -o -name 'rust-smoke' \) 2>/dev/null
```

Then run with that path, e.g. `docker run --rm <image> /workspace/bin/rust-smoke` or `/workspace/bin/rust_smoke`.

### Inspecting a saved image (which layer has the binary)

If you have a tarball from `docker save <image> > image.tar`, extract it and search layers for the binary path. From the directory that contains `blobs/` and `manifest.json` (e.g. after `tar -xvf image.tar`):

```bash
for f in blobs/sha256/*; do [ -f "$f" ] && out=$(tar -tf "$f" 2>/dev/null | grep -E 'rust_smoke|rust-smoke|/bin/' || true) && [ -n "$out" ] && echo "=== $f ===" && echo "$out"; done
```

Use the printed path (e.g. `workspace/bin/rust-smoke`) as the run path: `docker run --rm <image> /workspace/bin/rust-smoke`.

## Design

See [DESIGN.md](DESIGN.md) for host-aware patterns, target handling, and arm7/jemalloc notes.
