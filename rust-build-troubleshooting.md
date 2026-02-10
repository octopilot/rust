# Running the Rust smoke sample locally

Use these steps to build and run the Rust smoke test app with the builder image locally. You get full `pack build` output so you can see why a build might fail.

**Prerequisites:** Docker, [pack](https://github.com/buildpacks/pack) CLI, and (to build the builder) the builder's buildpack images must be pullable (e.g. `ghcr.io/octopilot/rust`).

From the **builder-jammy-base** repo root:

## 1. Create the builder image (once)

Uses `builder.toml` (including `ghcr.io/octopilot/rust`). Builds locally; no push.

```bash
pack builder create octopilot-builder-jammy-base --config builder.toml
```

If your builder is already published (e.g. after push-image-ghcr):

```bash
docker pull ghcr.io/octopilot/builder-jammy-base:latest
# Use that as the builder in step 2: --builder ghcr.io/octopilot/builder-jammy-base:latest
```

## 2. Build the Rust sample app

Use the builder from step 1 and the smoke Rust testdata:

```bash
pack build rust-smoke-app \
  --path smoke/testdata/rust \
  --builder octopilot-builder-jammy-base \
  --pull-policy always
```

Or with the published builder:

```bash
pack build rust-smoke-app \
  --path smoke/testdata/rust \
  --builder ghcr.io/octopilot/builder-jammy-base:latest \
  --pull-policy always
```

Optional: build in **debug** mode (faster compile, larger binary):

```bash
pack build rust-smoke-app \
  --path smoke/testdata/rust \
  --builder octopilot-builder-jammy-base \
  --env BP_RUST_BUILD_PROFILE=debug \
  --pull-policy always
```

## 3. Run the app

Default process (if the builder includes the launch process):

```bash
docker run --rm -e PORT=8080 -p 8080:8080 rust-smoke-app
```

If you see *"no default process"*, run the binary explicitly. The path depends on the run image (app dir is set by the stack). The smoke app binary may be named `rust_smoke` or `rust-smoke`. Find it with:

```bash
docker run --rm --entrypoint find rust-smoke-app / -type f \( -name 'rust_smoke' -o -name 'rust-smoke' \) 2>/dev/null
```

Then run with that path. For the jammy stack the app is under `/workspace/bin/` (e.g. `/workspace/bin/rust-smoke` or `/workspace/bin/rust_smoke`):

```bash
docker run --rm -e PORT=8080 -p 8080:8080 rust-smoke-app /workspace/bin/rust-smoke
# or, if find showed rust_smoke:
# docker run --rm -e PORT=8080 -p 8080:8080 rust-smoke-app /workspace/bin/rust_smoke
```

In another terminal:

```bash
curl -s http://localhost:8080
# expect: ok
```

## 4. Clean up

```bash
docker rmi rust-smoke-app
# optional: docker rmi octopilot-builder-jammy-base
```

---

**If the binary isn't found** (e.g. `find` returns nothing), the app layer may not be in the image. Rebuild the image after ensuring the Rust buildpack writes the default process (see buildpack `bin/build`: it should write `launch.toml` into the rust layer and copy the binary to `OUTPUT_DIR/bin/<name>`). Then rebuild the **builder** so it includes the updated Rust buildpack, and run `pack build` again.

If `pack build` fails, the logs will show which buildpack failed and why (e.g. Rust install, `cargo build`, or missing binary).

---

## Inspecting a saved image (optional)

If you exported the image with `docker save rust-smoke-app > image.tar` and extracted it (`mkdir tmp && mv image.tar tmp && cd tmp && tar -xvf image.tar`), you can see which layer contains the app binary and at what path. From the directory that contains `blobs/` and `manifest.json` (e.g. `tmp/`):

```bash
for f in blobs/sha256/*; do [ -f "$f" ] && out=$(tar -tf "$f" 2>/dev/null | grep -E 'rust_smoke|rust-smoke|/bin/' || true) && [ -n "$out" ] && echo "=== $f ===" && echo "$out"; done
```

Use the paths printed (e.g. `workspace/bin/rust-smoke` or `workspace/bin/rust_smoke`) as the run path: `docker run --rm rust-smoke-app /workspace/bin/rust-smoke`.
