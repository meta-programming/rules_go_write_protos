GoProtoSrcsInfo = provider(
    "Info about generated Go protobuf source files",
    fields = {
        "files": "depset of generated files",
        "mappings": "dict mapping generated file path to source tree destination path",
    },
)

def _collect_go_proto_srcs_impl(target, ctx):
    # Only collect generated files from targets defined in the main repository.
    if target.label.workspace_name != "":
        return []

    files = []
    mappings = {}
    
    # 1. Collect from direct target's 'go_generated_srcs' output group
    if OutputGroupInfo in target:
        if hasattr(target[OutputGroupInfo], "go_generated_srcs"):
            for f in target[OutputGroupInfo].go_generated_srcs.to_list():
                files.append(f)
                # Map the file to target's package + base name
                dest = target.label.package + "/" + f.basename if target.label.package else f.basename
                mappings[f.path] = dest
                
    # 2. Transitive collection from deps/embed
    for attr in ["deps", "embed"]:
        if hasattr(ctx.rule.attr, attr):
            for dep in getattr(ctx.rule.attr, attr):
                if GoProtoSrcsInfo in dep:
                    files.extend(dep[GoProtoSrcsInfo].files.to_list())
                    mappings.update(dep[GoProtoSrcsInfo].mappings)
                    
    return [
        GoProtoSrcsInfo(
            files = depset(files),
            mappings = mappings,
        ),
    ]

collect_go_proto_srcs_aspect = aspect(
    implementation = _collect_go_proto_srcs_impl,
    attr_aspects = ["deps", "embed"],
)

WriteProtoConfigInfo = provider(
    "Provider to propagate sync configs",
    fields = {
        "files": "depset of generated files",
        "mappings": "dict mapping generated file path to destination path",
        "checked_in_files": "depset of checked-in source files",
    }
)

def _write_go_proto_srcs_impl(ctx):
    generated_files = []
    mappings = {}
    checked_in_files = list(ctx.files.checked_in_files)
    
    # 1. Collect from direct targets (srcs)
    for src in ctx.attr.srcs:
        if GoProtoSrcsInfo in src:
            generated_files.extend(src[GoProtoSrcsInfo].files.to_list())
            mappings.update(src[GoProtoSrcsInfo].mappings)
            
    # 2. Collect from additional_update_targets
    for target in ctx.attr.additional_update_targets:
        if WriteProtoConfigInfo in target:
            generated_files.extend(target[WriteProtoConfigInfo].files.to_list())
            mappings.update(target[WriteProtoConfigInfo].mappings)
            checked_in_files.extend(target[WriteProtoConfigInfo].checked_in_files.to_list())
            
    if not generated_files and not ctx.attr.additional_update_targets:
        fail("No generated Go proto files found in the provided targets.")
        
    # Remove duplicates
    unique_files = {}
    for f in generated_files:
        unique_files[f.path] = f
        
    unique_checked_in = {}
    for f in checked_in_files:
        unique_checked_in[f.path] = f
        
    # Generate JSON config
    config_file = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(
        output = config_file,
        content = json.encode(struct(
            mode = "sync",
            verbosity = ctx.attr.verbosity,
            suggested_update_target = ctx.attr.suggested_update_target,
            files = [struct(
                src = ctx.workspace_name + "/" + f.short_path if not f.short_path.startswith("../") else f.short_path[3:],
                dest = mappings[f.path],
            ) for f in unique_files.values()],
        ))
    )
    
    # Symlink the Go tool
    executable_file = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = executable_file,
        target_file = ctx.executable._syncer_tool,
        is_executable = True,
    )
    
    runfiles_files = list(unique_files.values()) + list(unique_checked_in.values()) + [config_file]
    
    return [
        DefaultInfo(
            executable = executable_file,
            runfiles = ctx.runfiles(files = runfiles_files),
        ),
        RunEnvironmentInfo(
            environment = {
                "CONFIG_JSON_PATH": ctx.workspace_name + "/" + config_file.short_path,
            }
        ),
        WriteProtoConfigInfo(
            files = depset(unique_files.values()),
            mappings = mappings,
            checked_in_files = depset(unique_checked_in.values()),
        ),
    ]

_write_go_proto_srcs_rule = rule(
    implementation = _write_go_proto_srcs_impl,
    attrs = {
        "srcs": attr.label_list(
            aspects = [collect_go_proto_srcs_aspect],
            mandatory = False,
        ),
        "checked_in_files": attr.label_list(
            allow_files = True,
            mandatory = False,
        ),
        "additional_update_targets": attr.label_list(
            providers = [WriteProtoConfigInfo],
            mandatory = False,
        ),
        "verbosity": attr.string(
            default = "full",
            values = ["full", "short", "quiet"],
        ),
        "suggested_update_target": attr.string(
            mandatory = False,
        ),
        "_syncer_tool": attr.label(
            default = "//tools/copy_generated_proto_sources",
            executable = True,
            cfg = "exec",
        ),
    },
    executable = True,
)

def _write_go_proto_srcs_test_impl(ctx):
    executable_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.symlink(
        output = executable_file,
        target_file = ctx.executable.binary,
        is_executable = True,
    )
    return [
        DefaultInfo(
            executable = executable_file,
            runfiles = ctx.attr.binary[DefaultInfo].default_runfiles,
        ),
    ]

_write_go_proto_srcs_test = rule(
    implementation = _write_go_proto_srcs_test_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            cfg = "target",
            mandatory = True,
        ),
    },
    test = True,
)

def write_go_proto_srcs(
        name,
        srcs = [],
        additional_update_targets = [],
        diff_test = True,
        verbosity = "full",
        suggested_update_target = None,
        **kwargs):
    """Registers targets to synchronize and verify generated Go protobuf files.

    This macro instantiates:
      1. An executable sync target (`{name}`) that copies Bazel's output
         tree `.pb.go` files back into the user's workspace source directory.
      2. If `diff_test` is True, a hermetic test target (`{name}_test`) that
         verifies no drift exists between the workspace files and the
         generated Bazel runfiles.

    Args:
        name: A unique name for this target. The test target is named `{name}_test`.
        srcs: A list of `go_proto_library` targets whose generated Go sources
            should be tracked and synchronized.
        additional_update_targets: A list of other `write_go_proto_srcs` targets
            whose configurations and runfiles should be transitively aggregated.
            Useful for creating a single root-level synchronization target.
        diff_test: If True, generates a corresponding `{name}_test` target.
        verbosity: Verbosity level of the sync command outputs. One of `"full"`,
            `"short"`, or `"quiet"`.
        suggested_update_target: An optional suggested sync target path to print
            in the test failure error messages (e.g. `//:update_protos`).
        **kwargs: Common target attributes like `visibility`, `tags`, etc.
    """
    # Glob the checked-in files in the current package directory
    checked_in_files = native.glob(["*.pb.go"], allow_empty = True)
    
    # Default visibility to public so sub-packages' targets are visible to parent/root targets.
    if "visibility" not in kwargs:
        kwargs["visibility"] = ["//visibility:public"]

    tags = kwargs.pop("tags", [])
    
    _write_go_proto_srcs_rule(
        name = name,
        srcs = srcs,
        checked_in_files = checked_in_files,
        additional_update_targets = additional_update_targets,
        verbosity = verbosity,
        suggested_update_target = suggested_update_target if suggested_update_target else "",
        tags = tags,
        **kwargs
    )
    
    if diff_test:
        _write_go_proto_srcs_test(
            name = name + "_test",
            binary = ":" + name,
            tags = tags,
            visibility = kwargs.get("visibility"),
        )
