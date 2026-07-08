# Feasibility Study: Code Generation Synchronization for Java and Kotlin

This document investigates whether a bzlmod project similar to `rules_go_write_protos` is feasible and valuable for `rules_java` (Java) and `rules_kotlin` (Kotlin) to synchronize and verify generated protobuf sources in the workspace source tree.

---

## Motivation

In standard Java and Kotlin Bazel development, developers do not interact with generated source files on disk. The `java_proto_library` or Kotlin equivalents compile generated `.java`/`.kt` source files directly into a `.jar` archive and expose the source files inside a compiled source jar (`.srcjar`). IDEs like IntelliJ IDEA or Android Studio (using the Bazel plugin) resolve these via the `.srcjar` to provide autocompletion.

However, checking in generated Java/Kotlin sources is highly valuable in several contexts:
1. **Hybrid Build Systems**: Teams transitioning to Bazel that still support Gradle or Maven for local development or CI pipelines.
2. **IDE Integration without Bazel Plugins**: Facilitates native indexing, code navigation, and refactoring in standard IDE setups (IntelliJ, Eclipse, Android Studio) without requiring the Bazel plugin.
3. **External Distribution**: Distributing client SDK libraries as clean source trees to non-Bazel consumers.

---

## Proposed API Design

A similar API mapping makes complete sense. We can define:
- `write_java_proto_srcs` (for Java)
- `write_kt_proto_srcs` (for Kotlin)

### Registration Example
```python
load("@rules_java_write_protos//rules:defs.bzl", "write_java_proto_srcs")

write_java_proto_srcs(
    name = "update_java_protos",
    srcs = [
        "//pkg/foo:foo_java_proto",
    ],
    # Maps Java packages to their output source folders
    out_dir_map = {
        "com.example.project.foo": "src/main/java/com/example/project/foo",
    },
)
```

---

## Technical Challenges & Language-Specific Issues

Unlike Go, where `.pb.go` generated source files are direct outputs of target output groups, Java and Kotlin introduce several complexities:

### 1. The Dynamic Output Filenames Problem (The `.srcjar` Archive)
A `java_proto_library` outputs a single zipped `.srcjar` file containing all generated files. 
* **The Issue**: Starlark rules must declare all output files during the analysis phase. However, the exact files generated inside the `.srcjar` depend on `.proto` options such as `java_multiple_files` and `java_outer_classname`:
  - If `option java_multiple_files = false;` (default): A single outer class file is generated (e.g. `FooOuterClass.java`).
  - If `option java_multiple_files = true;`: Separate files are generated for each message, enum, and service (e.g. `MessageA.java`, `MessageB.java`).
* **The Solution**: 
  Instead of having the Starlark aspect track and output individual file mappings, the Starlark rule should pass the whole `.srcjar` target to the synchronization/test tool. The synchronization tool (written in Go or Python) will:
  - Extract the `.srcjar` to a temporary directory at execution time.
  - Perform a **directory-to-directory comparison** (for verification tests) or copy files directory-to-directory (for synchronization).
  - This avoids needing to declare dynamic generated filenames in Starlark.

### 2. Package Directory Hierarchy Constraints
Go is flexible about where package source files reside as long as they are compiled together, but Java and Kotlin compilers/IDEs strictly expect source files to reside in a directory structure that matches their package declaration:
- If a file declares `package com.example.foo;`, it must be placed in a directory matching `.../com/example/foo/Bar.java`.
- If the directory structure diverges from the package name, standard IDEs (like IntelliJ) will show syntax warnings, and build tools (like Gradle) might fail compilation.

* **Feasibility**:
  To support this, the synchronization tool should inspect the package structure within the extracted `.srcjar` (which natively matches the Java package structure) and map the root of the extracted tree to the specified base destination path (e.g. `src/main/java`).

---

## Conclusion & Recommendation

Implementing `write_java_proto_srcs` and `write_kt_proto_srcs` is **highly feasible** and shares a very similar API structure to `write_go_proto_srcs`. 

The key design difference is that the aspect should collect and propagate `.srcjar` files instead of individual source files, and the underlying copy/drift-detection tool must operate on directory trees (extracting the `.srcjar` and comparing directories recursively) rather than comparing individual files list-by-list.
