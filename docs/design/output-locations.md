# Design Document: Custom Output Locations

We evaluate how to allow users to customize the destination directory where synchronized `.pb.go` files are written in the source tree, rather than defaulting to the package directory of the `go_proto_library` target.

---

## Background: Go Protobuf File Sets and Dependencies

A typical Bazel Go workspace defines proto packages across different directories, often with complex inter-dependencies.

### Example Scenario
Suppose we have a local project `github.com/example/project` (the main workspace), which depends on:
1. A local `user` proto package.
2. A third-party Bazel module dependency `com_github_example_other_module` containing a `message` proto package.
3. Google's well-known `timestamp.proto` imported from `@protobuf`.

#### Workspace Source Tree
```text
/workspace/source
├── MODULE.bazel
├── pkg/
│   ├── user/
│   │   ├── BUILD.bazel
│   │   └── user.proto
│   └── billing/
│       ├── BUILD.bazel
│       └── billing.proto
```

#### Proto Definitions
1. **`pkg/user/user.proto`**:
   ```protobuf
   syntax = "proto3";
   package pkg.user;
   option go_package = "github.com/example/project/pkg/user";
   
   message User { string id = 1; }
   ```
2. **`@com_github_example_other_module//pkg/message:message.proto`** (3rd-party proto):
   ```protobuf
   syntax = "proto3";
   package pkg.message;
   option go_package = "github.com/example/other_module/pkg/message";
   
   message ExtraInfo { string details = 1; }
   ```
3. **`pkg/billing/billing.proto`**:
   ```protobuf
   syntax = "proto3";
   package pkg.billing;
   import "google/protobuf/timestamp.proto";
   import "pkg/user/user.proto";
   import "pkg/message/message.proto"; // imported from external module
   option go_package = "github.com/example/project/pkg/billing";
   
   message Invoice {
       pkg.user.User user = 1;
       pkg.message.ExtraInfo info = 2;
       google.protobuf.Timestamp issued_at = 3;
   }
   ```

---

## What are the compiled outputs?

When Bazel compiles the `go_proto_library` targets, it generates Go source files for each proto package inside the Bazel output tree (`bazel-bin`).

### Directory Tree: Bazel Output Tree (`bazel-bin`)
```text
bazel-bin/
├── pkg/
│   ├── user/
│   │   └── user_go_proto_/
│   │       └── github.com/
│   │           └── example/
│   │               └── project/
│   │                   └── pkg/
│   │                       └── user/
│   │                           └── user.pb.go
│   └── billing/
│       └── billing_go_proto_/
│           └── github.com/
│               └── example/
│                   └── project/
│                       └── pkg/
│                           └── billing/
│                               └── billing.pb.go
└── external/
    └── com_github_example_other_module+/
        └── pkg/
            └── message/
                └── message_go_proto_/
                    └── github.com/
                        └── example/
                            └── other_module/
                                └── pkg/
                                    └── message/
                                        └── message.pb.go
```

*   **Main Workspace Targets**: `user.pb.go` and `billing.pb.go` are generated locally.
*   **External Dependencies**: `message.pb.go` is generated under Bazel's `external/` directory, while `google.protobuf.Timestamp` is resolved via precompiled types from `@org_golang_google_protobuf`.

---

## Destination Tree (Workspace Source Tree)

The Starlark aspect `collect_go_proto_srcs_aspect` filters out any targets belonging to external workspaces (like `@com_github_example_other_module` and `@org_golang_google_protobuf`). Thus, only local files are tracked and synchronized back to the source tree.

By default, the synced destination files in the source tree are mapped directly to their home package directories:
```text
/workspace/source
├── pkg/
│   ├── user/
│   │   ├── BUILD.bazel
│   │   ├── user.proto
│   │   └── user.pb.go        <-- Synced from bazel-bin
│   └── billing/
│       ├── BUILD.bazel
│       ├── billing.proto
│       └── billing.pb.go     <-- Synced from bazel-bin
```
*(Notice that `message.pb.go` is not copied into `/workspace/source` because it is owned by the external workspace.)*

If we want to customize where these outputs are written in the source tree, we need a mechanism to redirect these destination paths.

---

## Proposed Options

To enable maximum flexibility, the macro will support both options with aligned names:

### 1. `out_dir` (Package-Level Override)
Overrides the base directory for all outputs compiled by targets in `srcs`.

#### API Design
```python
write_go_proto_srcs(
    name = "update_protos",
    srcs = [":foo_go_proto"],
    out_dir = "pkg/generated",  # All output files written to pkg/generated/
)
```

---

### 2. `out_dir_map` (Target-Level Mapping Dictionary)
Allows mapping individual `go_proto_library` targets to different custom destination directories.

#### API Design
```python
write_go_proto_srcs(
    name = "update_protos",
    srcs = [":foo_go_proto", ":bar_go_proto"],
    out_dir_map = {
        ":foo_go_proto": "pkg/generated/foo",
        ":bar_go_proto": "pkg/generated/bar",
    },
)
```

---

## Unmapped Target Behavior Policy

If `out_dir_map` is specified but a source target is missing from the dictionary, we define a validation policy via `out_dir_map_mode` to clarify developer intent and ensure repository correctness.

We propose the following validation modes for `out_dir_map_mode` (default is `"local"`):

| Mode | Behavior | Description |
| :--- | :--- | :--- |
| `"strict"` | Fail on any unmapped target | Every target processed by the aspect (including external dependencies if tracked) must be explicitly mapped in `out_dir_map`. If any are missing, analysis fails. |
| `"local"` | Fail on unmapped local targets | Every target in the local workspace must be mapped. External dependencies are ignored. Ideal for ensuring all workspace targets are accounted for. |
| `"loose"` | Fallback to package directory | Unmapped targets silently fall back to using their target's package directory (the default behavior). |

---

## FAQ

**Q**: Is filtering out external workspace targets (like `@com_github_example_other_module`) *always* the right behavior?
**A**: Generally yes, because 3rd-party dependencies should be fetched and compiled hermetically rather than duplicated in the local workspace source tree. However, under air-gapped or offline deployment constraints, teams might need to vendor all generated code locally.
If this is required, we can introduce a boolean `sync_external_deps` attribute (defaulting to `False`). If set to `True`, the aspect will include external dependencies, and they can be mapped under a custom vendor folder (e.g. `vendor/github.com/example/other_module/...`).

**Q**: Could `out_dir_map` be based on the Go package name (importpath) instead of the Bazel target label?
**A**: Yes. Mapping by Go package name (e.g., `github.com/example/project/pkg/user`) is highly intuitive and stable.
*   **How it works**: The Starlark aspect reads the `importpath` of each `go_proto_library` target. During rule execution, instead of matching targets by their Bazel label, we match by their `importpath` string.
*   **Pros**: Agnostic to Bazel label name reorganizations. Aligning directory structure to Go packages is standard practice in Go development.
*   **Cons**: Lacks Bazel label validation (Starlark won't detect typos in Go import paths at configuration-load time).
*   **Proposed Extension**: We can support *both* by allowing keys in `out_dir_map` to be either:
    1. A Bazel target label (resolved using label-keyed dictionaries `attr.label_keyed_string_dict`).
    2. A Go import path string (resolved via a string-keyed fallback dictionary `out_importpath_map = attr.string_dict()`).
