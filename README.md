# rules_go_proto_sync

A Bazel 9 ruleset providing aspect-driven synchronization of Bazel-generated Go protobuf source files back into your project's source tree.

## Why use this?

When using `rules_go`, Go protobuf bindings (`.pb.go`) are generated inside Bazel's output sandbox (`bazel-out/`). While this is perfect for hermetic builds, it causes issues for standard Go tooling (e.g. `go build`, `go test`) and IDEs (VS Code, GoLand) which cannot locate the generated packages and display "unresolved import" errors.

`rules_go_proto_sync` solves this by automatically discovering all generated `.pb.go` files for a target using a custom Starlark aspect and copying them to their corresponding package folders in your source tree via `bazel run`. It also provides a drift-detection test to ensure checked-in files never get out of sync.

---

## Quickstart

### 1. Configure Bzlmod
Add the following to your `MODULE.bazel`:

```python
module(
    name = "my_project",
    version = "0.0.0",
)

# Fetch rules_go_proto_sync from Git (or BCR when available)
git_override(
    module_name = "rules_go_proto_sync",
    remote = "https://github.com/gonzojive/rules_go_proto_sync.git",
    commit = "[latest-commit-hash]", # Replace with the latest commit hash
)

bazel_dep(name = "rules_go_proto_sync", version = "0.0.0")
bazel_dep(name = "rules_go", version = "0.61.1")
bazel_dep(name = "rules_proto", version = "7.1.0")
bazel_dep(name = "protobuf", version = "33.4")
```

### 2. Define Protobuf Targets
In your package `BUILD.bazel` (e.g., `pkg/foo/BUILD.bazel`):

```python
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_go//proto:def.bzl", "go_proto_library")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
    visibility = ["//visibility:public"],
)

go_proto_library(
    name = "foo_go_proto",
    importpath = "github.com/example/project/pkg/foo",
    proto = ":foo_proto",
    visibility = ["//visibility:public"],
)
```

### 3. Load and Register the Sync Macro
In your root `BUILD.bazel` file:

```python
load("@rules_go_proto_sync//rules:defs.bzl", "write_go_proto_sources")

write_go_proto_sources(
    name = "update_protos",
    srcs = [
        "//pkg/foo:foo_go_proto",
    ],
)
```

### 4. Sync Generated Files
Run the executable sync target to copy generated `.pb.go` files into the source tree:

```bash
bazel run //:update_protos
```

This will write the files to `pkg/foo/foo.pb.go` and mark them writable (`chmod +w`).

### 5. Verify Drift (CI & Local Checks)
A companion test target `[name]_test` is automatically created. To verify that checked-in files match what Bazel generates:

```bash
bazel test //:update_protos_test
```

This test runs outside the sandbox, does not cache results, and will fail with a file diff if any checked-in files are out of sync.

---

## Fast Builds (Precompiled Protoc)

To avoid compiling `protoc` from source (which can slow down initial Bazel runs significantly), add the following to your `.bazelrc`:

```text
# Use prebuilt protoc binaries from GitHub releases
common --@protobuf//bazel/toolchains:prefer_prebuilt_protoc
```

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.
