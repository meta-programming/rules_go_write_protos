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
        
    # Generate copying script
    script_content = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        'if [ -z "${BUILD_WORKSPACE_DIRECTORY}" ]; then',
        '  echo "Error: This target must be run with \'bazel run\'" >&2',
        "  exit 1",
        "fi",
        "",
        '# Locate runfiles directory',
        'if [ -z "${RUNFILES_DIR:-}" ]; then',
        '  if [ -d "${BASH_SOURCE[0]}.runfiles" ]; then',
        '    RUNFILES_DIR="${BASH_SOURCE[0]}.runfiles"',
        '  elif [ -d "$(dirname "$0")/$(basename "$0").runfiles" ]; then',
        '    RUNFILES_DIR="$(dirname "$0")/$(basename "$0").runfiles"',
        '  elif [ -d "${TEST_SRCDIR:-}" ]; then',
        '    RUNFILES_DIR="${TEST_SRCDIR}"',
        '  else',
        '    echo "Error: Could not locate runfiles directory." >&2',
        '    exit 1',
        '  fi',
        'fi',
        "",
    ]
    
    workspace_name = ctx.workspace_name
    
    for path, f in unique_files.items():
        # Get target destination path from mappings
        dest_path = mappings[path]
        runfiles_rel_path = "{}/{}".format(workspace_name, f.short_path)
        
        script_content.append('DEST_FILE="${{BUILD_WORKSPACE_DIRECTORY}}/{0}"'.format(dest_path))
        script_content.append('mkdir -p "$(dirname "${DEST_FILE}")"')
        script_content.append('cp -f "${{RUNFILES_DIR}}/{0}" "${{DEST_FILE}}"'.format(runfiles_rel_path))
        script_content.append('chmod +w "${DEST_FILE}"')
        script_content.append('echo "Updated: {0}"'.format(dest_path))
        
    executable_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = executable_file,
        content = "\n".join(script_content) + "\n",
        is_executable = True,
    )
    
    return [
        DefaultInfo(
            executable = executable_file,
            runfiles = ctx.runfiles(files = unique_files.values()),
        ),
    ]

write_go_proto_srcs = rule(
    implementation = _write_go_proto_srcs_impl,
    attrs = {
        "srcs": attr.label_list(
            aspects = [collect_go_proto_srcs_aspect],
            mandatory = True,
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
        
    script_content = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        '# Locate runfiles directory',
        'if [ -z "${RUNFILES_DIR:-}" ]; then',
        '  if [ -d "${BASH_SOURCE[0]}.runfiles" ]; then',
        '    RUNFILES_DIR="${BASH_SOURCE[0]}.runfiles"',
        '  elif [ -d "$(dirname "$0")/$(basename "$0").runfiles" ]; then',
        '    RUNFILES_DIR="$(dirname "$0")/$(basename "$0").runfiles"',
        '  elif [ -d "${TEST_SRCDIR:-}" ]; then',
        '    RUNFILES_DIR="${TEST_SRCDIR}"',
        '  else',
        '    echo "Error: Could not locate runfiles directory." >&2',
        '    exit 1',
        '  fi',
        'fi',
        "",
        "# Resolve the real path of the workspace root by following the MODULE.bazel symlink",
        'WORKSPACE_MARKER_PATH="${RUNFILES_DIR}/_main/MODULE.bazel"',
        'if [ ! -f "${WORKSPACE_MARKER_PATH}" ]; then',
        '  # Fallback to finding MODULE.bazel in runfiles directory',
        '  WORKSPACE_MARKER_PATH=$(find "${RUNFILES_DIR}" -name MODULE.bazel -print -quit)',
        "fi",
        "",
        'if [ -z "${WORKSPACE_MARKER_PATH}" ] || [ ! -f "${WORKSPACE_MARKER_PATH}" ]; then',
        '  echo "Error: Could not locate workspace marker file (MODULE.bazel) in runfiles." >&2',
        "  exit 1",
        "fi",
        "",
        'REAL_MARKER_PATH=$(readlink -f "${WORKSPACE_MARKER_PATH}" || realpath "${WORKSPACE_MARKER_PATH}")',
        'WORKSPACE_ROOT=$(dirname "${REAL_MARKER_PATH}")',
        "",
        "FAILED=0",
    ]
    
    workspace_name = ctx.workspace_name
    
    for path, f in unique_files.items():
        dest_path = mappings[path]
        runfiles_rel_path = "{}/{}".format(workspace_name, f.short_path)
        
        script_content.append('SOURCE_FILE="${{WORKSPACE_ROOT}}/{0}"'.format(dest_path))
        script_content.append('GENERATED_FILE="${{RUNFILES_DIR}}/{0}"'.format(runfiles_rel_path))
        script_content.append('if [ ! -f "${SOURCE_FILE}" ]; then')
        script_content.append('  echo "Error: Source file does not exist in workspace: {0}" >&2'.format(dest_path))
        script_content.append("  FAILED=1")
        script_content.append('elif ! diff -u "${SOURCE_FILE}" "${GENERATED_FILE}" >/dev/null; then')
        script_content.append('  echo "Error: Source file out of sync: {0}" >&2'.format(dest_path))
        script_content.append('  echo "Diff:" >&2')
        script_content.append('  diff -u "${SOURCE_FILE}" "${GENERATED_FILE}" || true')
        script_content.append("  FAILED=1")
        script_content.append("fi")
        script_content.append("")
        
    script_content.append('if [ "${FAILED}" -ne 0 ]; then')
    script_content.append('  echo "Verification failed. Run the update target to sync generated files." >&2')
    script_content.append("  exit 1")
    script_content.append("else")
    script_content.append('  echo "All generated Go proto files are up to date!"')
    script_content.append("  exit 0")
    script_content.append("fi")
    
    executable_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = executable_file,
        content = "\n".join(script_content) + "\n",
        is_executable = True,
    )
    
    runfiles_files = list(unique_files.values()) + [ctx.file._workspace_marker]
    
    return [
        DefaultInfo(
            executable = executable_file,
            runfiles = ctx.runfiles(files = runfiles_files),
        ),
    ]

check_go_proto_srcs_test = rule(
    implementation = _check_go_proto_srcs_impl,
    attrs = {
        "srcs": attr.label_list(
            aspects = [collect_go_proto_srcs_aspect],
            mandatory = True,
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
