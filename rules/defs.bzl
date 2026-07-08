GoProtoSrcsInfo = provider(
    "Info about generated Go protobuf source files",
    fields = {
        "files": "depset of generated files",
        "mappings": "dict mapping generated file path to source tree destination path",
        "file_to_importpath": "dict mapping generated file path to its target importpath",
    },
)

def _collect_go_proto_srcs_impl(target, ctx):
    # Only collect generated files from targets defined in the main repository.
    if target.label.workspace_name != "":
        return []

    files = []
    mappings = {}
    file_to_importpath = {}
    
    # Get direct target importpath if available (e.g. from go_proto_library attributes)
    importpath = getattr(ctx.rule.attr, "importpath", "")
    
    # 1. Collect from direct target's 'go_generated_srcs' output group
    if OutputGroupInfo in target:
        if hasattr(target[OutputGroupInfo], "go_generated_srcs"):
            for f in target[OutputGroupInfo].go_generated_srcs.to_list():
                files.append(f)
                # Map the file to target's package + base name
                dest = target.label.package + "/" + f.basename if target.label.package else f.basename
                mappings[f.path] = dest
                if importpath:
                    file_to_importpath[f.path] = importpath
                
    # 2. Transitive collection from deps/embed
    for attr in ["deps", "embed"]:
        if hasattr(ctx.rule.attr, attr):
            for dep in getattr(ctx.rule.attr, attr):
                if GoProtoSrcsInfo in dep:
                    files.extend(dep[GoProtoSrcsInfo].files.to_list())
                    mappings.update(dep[GoProtoSrcsInfo].mappings)
                    if hasattr(dep[GoProtoSrcsInfo], "file_to_importpath"):
                        file_to_importpath.update(dep[GoProtoSrcsInfo].file_to_importpath)
                    
    return [
        GoProtoSrcsInfo(
            files = depset(files),
            mappings = mappings,
            file_to_importpath = file_to_importpath,
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
        "file_to_importpath": "dict mapping generated file path to target importpath",
    }
)

def _write_go_proto_srcs_impl(ctx):
    if ctx.attr.out_dir and ctx.attr.out_dir_map:
        fail("Cannot set both out_dir and out_dir_map on target %s." % ctx.label)

    generated_files = []
    mappings = {}
    file_to_importpath = {}
    checked_in_files = list(ctx.files.checked_in_files)
    
    # 1. Collect from direct targets (srcs)
    for src in ctx.attr.srcs:
        if GoProtoSrcsInfo in src:
            generated_files.extend(src[GoProtoSrcsInfo].files.to_list())
            mappings.update(src[GoProtoSrcsInfo].mappings)
            if hasattr(src[GoProtoSrcsInfo], "file_to_importpath"):
                file_to_importpath.update(src[GoProtoSrcsInfo].file_to_importpath)
            
    # 2. Collect from additional_update_targets
    for target in ctx.attr.additional_update_targets:
        if WriteProtoConfigInfo in target:
            generated_files.extend(target[WriteProtoConfigInfo].files.to_list())
            mappings.update(target[WriteProtoConfigInfo].mappings)
            checked_in_files.extend(target[WriteProtoConfigInfo].checked_in_files.to_list())
            if hasattr(target[WriteProtoConfigInfo], "file_to_importpath"):
                file_to_importpath.update(target[WriteProtoConfigInfo].file_to_importpath)
            
    if not generated_files and not ctx.attr.additional_update_targets:
        fail("No generated Go proto files found in the provided targets.")
        
    # Remove duplicates
    unique_files = {}
    for f in generated_files:
        unique_files[f.path] = f
        
    unique_checked_in = {}
    for f in checked_in_files:
        unique_checked_in[f.path] = f
        
    # Resolve mapped destination paths
    final_mappings = {}
    for f in unique_files.values():
        dest = mappings[f.path]
        importpath = file_to_importpath.get(f.path, "")
        
        if ctx.attr.out_dir:
            dest = ctx.attr.out_dir + "/" + f.basename
        elif ctx.attr.out_dir_map:
            if importpath in ctx.attr.out_dir_map:
                dest = ctx.attr.out_dir_map[importpath] + "/" + f.basename
            else:
                if ctx.attr.out_dir_map_strictness in ["strict", "local"]:
                    fail("Importpath '%s' of generated file '%s' is not mapped in out_dir_map." % (importpath, f.path))
                # If loose, keep default package destination
        
        final_mappings[f.path] = dest

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
                dest = final_mappings[f.path],
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
            mappings = final_mappings,
            checked_in_files = depset(unique_checked_in.values()),
            file_to_importpath = file_to_importpath,
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
        "out_dir": attr.string(
            mandatory = False,
        ),
        "out_dir_map": attr.string_dict(
            mandatory = False,
        ),
        "out_dir_map_strictness": attr.string(
            default = "local",
            values = ["strict", "local", "loose"],
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
        out_dir = None,
        out_dir_map = {},
        out_dir_map_strictness = "local",
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
        out_dir: An optional package-level directory override. If specified,
            all generated files will be synchronized directly into this folder.
        out_dir_map: An optional string dictionary mapping Go importpath strings
            (e.g., `"github.com/example/project/pkg/foo"`) to custom destination
            directories.
        out_dir_map_strictness: The policy to handle targets processed by the
            aspect that are not specified in the `out_dir_map` configuration.
            One of `"strict"` (fail on any missing target), `"local"` (fail on
            missing local workspace targets), or `"loose"` (silently fall back).
        **kwargs: Common target attributes like `visibility`, `tags`, etc.
    """
    # Determine the package-relative paths to glob for checked-in files.
    checked_in_patterns = []
    package = native.package_name()
    
    if out_dir:
        # Strip the current package name prefix from the output path
        rel = out_dir
        if package != "":
            prefix = package + "/"
            if out_dir.startswith(prefix):
                rel = out_dir[len(prefix):]
            elif out_dir == package:
                rel = ""
            else:
                rel = None
        if rel != None:
            checked_in_patterns.append(rel + "/*.pb.go" if rel else "*.pb.go")
    elif out_dir_map:
        for path in out_dir_map.values():
            rel = path
            if package != "":
                prefix = package + "/"
                if path.startswith(prefix):
                    rel = path[len(prefix):]
                elif path == package:
                    rel = ""
                else:
                    rel = None
            if rel != None:
                checked_in_patterns.append(rel + "/*.pb.go" if rel else "*.pb.go")
    else:
        checked_in_patterns.append("*.pb.go")
        
    checked_in_files = []
    if checked_in_patterns:
        checked_in_files = native.glob(checked_in_patterns, allow_empty = True)
    
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
        out_dir = out_dir if out_dir else "",
        out_dir_map = out_dir_map,
        out_dir_map_strictness = out_dir_map_strictness,
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
