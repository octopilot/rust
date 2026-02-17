## PR Description: Custom Rust Buildpack

### Problem
We needed a lightweight, performant Cloud Native Buildpack for Rust applications that integrates seamlessly with our `builder-jammy-base` stack and handles dependency caching efficiently according to our pipeline standards.

### Changes
-   **Toolchain Handling**: Implemented logic to detect `Cargo.toml` and install the appropriate Rust toolchain.
-   **Build Process**: Executes `cargo build --release` and correctly exports the binary layer.
-   **Caching**: Caches `target/` and Cargo registry directories to speed up subsequent builds.

### Verification
Verified by building the `sample-static-rust-axum` project.
-   **Detection**: Correctly identifies Rust projects.
-   **Build**: Successfully compiles the Axum API.
-   **Run**: The generated OCI image launches the API service as expected.
