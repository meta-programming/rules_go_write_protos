GoProtoSrcsInfo = provider(
    "Info about generated Go protobuf source files",
    fields = {
        "files": "depset of generated files",
        "mappings": "dict mapping generated file path to source tree destination path",
    },
)

def _collect_go_proto_srcs_impl(target, ctx):
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

def _write_go_proto_srcs_impl(ctx):
    generated_files = []
    mappings = {}
    for src in ctx.attr.srcs:
        if GoProtoSrcsInfo in src:
            generated_files.extend(src[GoProtoSrcsInfo].files.to_list())
            mappings.update(src[GoProtoSrcsInfo].mappings)
            
    if not generated_files:
        fail("No generated Go proto files found in the provided targets.")
        
    # Remove duplicates
    unique_files = {}
    for f in generated_files:
        unique_files[f.path] = f
        
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
    
    runfiles_files = list(unique_files.values()) + [config_file]
    
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
    ]

write_go_proto_srcs = rule(
    implementation = _write_go_proto_srcs_impl,
    attrs = {
        "srcs": attr.label_list(
            aspects = [collect_go_proto_srcs_aspect],
            mandatory = True,
        ),
        "_syncer_tool": attr.label(
            default = "//tools/copy_generated_proto_sources",
            executable = True,
            cfg = "exec",
        ),
    },
    executable = True,
)

def _check_go_proto_srcs_impl(ctx):
    generated_files = []
    mappings = {}
    for src in ctx.attr.srcs:
        if GoProtoSrcsInfo in src:
            generated_files.extend(src[GoProtoSrcsInfo].files.to_list())
            mappings.update(src[GoProtoSrcsInfo].mappings)
            
    if not generated_files:
        fail("No generated Go proto files found in the provided targets.")
        
    # Remove duplicates
    unique_files = {}
    for f in generated_files:
        unique_files[f.path] = f
        
    # Generate JSON config
    config_file = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(
        output = config_file,
        content = json.encode(struct(
            mode = "check",
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
    
    runfiles_files = list(unique_files.values()) + [config_file, ctx.file._workspace_marker]
    
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
    ]

check_go_proto_srcs_test = rule(
    implementation = _check_go_proto_srcs_impl,
    attrs = {
        "srcs": attr.label_list(
            aspects = [collect_go_proto_srcs_aspect],
            mandatory = True,
        ),
        "_syncer_tool": attr.label(
            default = "//tools/copy_generated_proto_sources",
            executable = True,
            cfg = "exec",
        ),
        "_workspace_marker": attr.label(
            default = "//:MODULE.bazel",
            allow_single_file = True,
        ),
    },
    test = True,
)

def write_go_proto_sources(name, srcs, **kwargs):
    # Retrieve tags if passed
    tags = kwargs.pop("tags", [])
    if "local" not in tags:
        tags.append("local")
    if "no-sandbox" not in tags:
        tags.append("no-sandbox")
    if "no-cache" not in tags:
        tags.append("no-cache")
    if "external" not in tags:
        tags.append("external")
        
    write_go_proto_srcs(
        name = name,
        srcs = srcs,
        **kwargs
    )
    
    check_go_proto_srcs_test(
        name = name + "_test",
        srcs = srcs,
        tags = tags,
        **kwargs
    )
