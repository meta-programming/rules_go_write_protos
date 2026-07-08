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

### Option A: Package-Level Directory Override (Macro/Rule Level)
The macro accepts an optional `out_dir` (or `dest_base_path`) argument, which overrides the base directory for all outputs compiled by targets in `srcs`.

#### API Design
```python
write_go_proto_srcs(
    name = "update_protos",
    srcs = [":foo_go_proto"],
    out_dir = "pkg/generated",  # All output files written to pkg/generated/
)
```

#### Starlark Implementation
Inside the rule implementation (`_write_go_proto_srcs_impl`), we check if the `out_dir` attribute is specified. If so, we override the destination path of each generated file to use `out_dir` instead of the target's package:

```python
dest = mappings[f.path]
if ctx.attr.out_dir:
    dest = ctx.attr.out_dir + "/" + f.basename
```
*   **Pros**: Extremely simple Starlark implementation. Intuitive API.
*   **Cons**: All files from all targets in `srcs` are written to the same directory (no target-level granularity).

---

### Option B: Target-Level Mapping Dictionary
The macro accepts a dictionary mapping `go_proto_library` targets to their custom destination paths.

#### API Design
```python
write_go_proto_srcs(
    name = "update_protos",
    # Maps specific targets to custom directories
    srcs_mapping = {
        ":foo_go_proto": "pkg/generated/foo",
        ":bar_go_proto": "pkg/generated/bar",
    },
)
```

#### Starlark Implementation
1. We define an attribute `srcs_mapping = attr.label_keyed_string_dict(aspects = [collect_go_proto_srcs_aspect])`.
2. Inside the rule implementation, we iterate over the dictionary keys, retrieve their `GoProtoSrcsInfo`, and map the files to the directories specified in the values:

```python
for target, out_dir in ctx.attr.srcs_mapping.items():
    if GoProtoSrcsInfo in target:
        for f in target[GoProtoSrcsInfo].files.to_list():
            mappings[f.path] = out_dir + "/" + f.basename
```
*   **Pros**: High granularity. Different targets can be synced to different custom locations within a single macro call.
*   **Cons**: Slightly more complex to configure in the BUILD file.

---

## Recommendation

We recommend **Option A (Package-Level Override)** for simplicity if most use-cases just require moving all package protobuf files to a single folder (like `pkg/generated`).

If developers need to sync various targets to different directories within the same package macro, **Option B (Target-Level Mapping)** is the most flexible.
