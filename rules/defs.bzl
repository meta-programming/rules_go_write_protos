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

write_go_proto_srcs = rule(
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
        "_syncer_tool": attr.label(
            default = "//tools/copy_generated_proto_sources",
            executable = True,
            cfg = "exec",
        ),
    },
    executable = True,
)

def _check_go_proto_srcs_test_impl(ctx):
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

check_go_proto_srcs_test = rule(
    implementation = _check_go_proto_srcs_test_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            cfg = "target",
            mandatory = True,
        ),
    },
    test = True,
)

def write_go_proto_sources(name, srcs = [], additional_update_targets = [], **kwargs):
    # Glob the checked-in files in the current package directory
    checked_in_files = native.glob(["*.pb.go"], allow_empty = True)
    
    # Default visibility to public so sub-packages' targets are visible to parent/root targets.
    if "visibility" not in kwargs:
        kwargs["visibility"] = ["//visibility:public"]

    tags = kwargs.pop("tags", [])
    
    write_go_proto_srcs(
        name = name,
        srcs = srcs,
        checked_in_files = checked_in_files,
        additional_update_targets = additional_update_targets,
        tags = tags,
        **kwargs
    )
    
    check_go_proto_srcs_test(
        name = name + "_test",
        binary = ":" + name,
        tags = tags,
        visibility = kwargs.get("visibility"),
    )
