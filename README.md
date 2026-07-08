# rules_go_write_protos

A Bazel 9 ruleset providing aspect-driven synchronization of Bazel-generated Go protobuf source files back into your project's source tree.

## Why use this?

When using `rules_go`, Go protobuf bindings (`.pb.go`) are generated inside Bazel's output sandbox (`bazel-out/`). While this is perfect for hermetic builds, it causes issues for standard Go tooling (e.g. `go build`, `go test`) and IDEs (VS Code, GoLand) which cannot locate the generated packages and display "unresolved import" errors.

`rules_go_write_protos` solves this by automatically discovering all generated `.pb.go` files for a target using a custom Starlark aspect and copying them to their corresponding package folders in your source tree via `bazel run`. It also provides a drift-detection test to ensure checked-in files never get out of sync.

---


## Quickstart

### 1. Configure Bzlmod
Add the following to your `MODULE.bazel`:

```python
bazel_dep(name = "rules_go_write_protos", version = "0.0.1")
```

### 2. Define Targets and Register the Sync Macro

In your package `BUILD.bazel` (e.g., `pkg/foo/BUILD.bazel`), define your compilation targets:

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

In your root `BUILD.bazel` file, load and register the sync macro referencing the Go proto library:

```python
load("@rules_go_write_protos//rules:defs.bzl", "write_go_proto_srcs")

write_go_proto_srcs(
    name = "update_protos",
    srcs = [
        "//pkg/foo:foo_go_proto",
    ],
)

# Alternative: Mapping Go packages to custom directory structures.
# (Note: mapping to "pkg/foo" here is equivalent to the default package-based output.
# This is useful if you have .proto files in a "protos/foo" directory and want to
# output Go source files in a different directory, like "pkg/foo". This is because
# standard Go toolchains (using go.mod) expect package files to reside in the
# directory corresponding to their import path, whereas Bazel's rules_go is tolerant
# of Go packages being compiled from any location in the repository).
write_go_proto_srcs(
    name = "update_protos_custom",
    srcs = [
        "//pkg/foo:foo_go_proto",
    ],
    out_dir_map = {
        "github.com/example/project/pkg/foo": "pkg/foo",
    },
)
```

### 3. Sync Generated Files
Run the executable sync target to copy generated `.pb.go` files into the source tree:

```bash
bazel run //:update_protos
```

This will write the files to `pkg/foo/foo.pb.go` and mark them writable (`chmod +w`).

### 4. Verify Drift (CI & Local Checks)
A companion test target `[name]_test` is automatically created. To verify that checked-in files match what Bazel generates:

```bash
bazel test //:update_protos_test
```

This test runs outside the sandbox, does not cache results, and will fail with a file diff if any checked-in files are out of sync.


## FAQ

### Why can't I just use Aspect.dev's `write_source_files` directly?

Aspect.dev provides a standard [write_source_files](https://github.com/bazel-contrib/bazel-lib/blob/main/docs/write_source_files.md) rule (maintained in `bazel-lib`) to write generated files back to the source tree.

However, you cannot use it **directly** for Go protobufs because `write_source_files` expects direct outputs of Bazel targets. The generated `.pb.go` files are not direct outputs of `go_proto_library` (its default output is the compiled `.a` archive). Instead, they are exposed in the target's internal `go_generated_srcs` output group.

`rules_go_write_protos` solves this by using a custom Starlark aspect to traverse the target dependency graph, extract the hidden generated files from the output group, and automatically map them back to their package locations.

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.
