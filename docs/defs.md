<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="GoProtoSrcsInfo"></a>

## GoProtoSrcsInfo

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "GoProtoSrcsInfo")

GoProtoSrcsInfo(<a href="#GoProtoSrcsInfo-files">files</a>, <a href="#GoProtoSrcsInfo-mappings">mappings</a>)
</pre>

Info about generated Go protobuf source files

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="GoProtoSrcsInfo-files"></a>files |  depset of generated files    |
| <a id="GoProtoSrcsInfo-mappings"></a>mappings |  dict mapping generated file path to source tree destination path    |


<a id="WriteProtoConfigInfo"></a>

## WriteProtoConfigInfo

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "WriteProtoConfigInfo")

WriteProtoConfigInfo(<a href="#WriteProtoConfigInfo-files">files</a>, <a href="#WriteProtoConfigInfo-mappings">mappings</a>, <a href="#WriteProtoConfigInfo-checked_in_files">checked_in_files</a>)
</pre>

Provider to propagate sync configs

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="WriteProtoConfigInfo-files"></a>files |  depset of generated files    |
| <a id="WriteProtoConfigInfo-mappings"></a>mappings |  dict mapping generated file path to destination path    |
| <a id="WriteProtoConfigInfo-checked_in_files"></a>checked_in_files |  depset of checked-in source files    |


<a id="write_go_proto_srcs"></a>

## write_go_proto_srcs

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "write_go_proto_srcs")

write_go_proto_srcs(<a href="#write_go_proto_srcs-name">name</a>, <a href="#write_go_proto_srcs-srcs">srcs</a>, <a href="#write_go_proto_srcs-additional_update_targets">additional_update_targets</a>, <a href="#write_go_proto_srcs-diff_test">diff_test</a>, <a href="#write_go_proto_srcs-verbosity">verbosity</a>,
                    <a href="#write_go_proto_srcs-suggested_update_target">suggested_update_target</a>, <a href="#write_go_proto_srcs-kwargs">**kwargs</a>)
</pre>

Registers targets to synchronize and verify generated Go protobuf files.

This macro instantiates:
  1. An executable sync target (`{name}`) that copies Bazel's output
     tree `.pb.go` files back into the user's workspace source directory.
  2. If `diff_test` is True, a hermetic test target (`{name}_test`) that
     verifies no drift exists between the workspace files and the
     generated Bazel runfiles.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="write_go_proto_srcs-name"></a>name |  A unique name for this target. The test target is named `{name}_test`.   |  none |
| <a id="write_go_proto_srcs-srcs"></a>srcs |  A list of `go_proto_library` targets whose generated Go sources should be tracked and synchronized.   |  `[]` |
| <a id="write_go_proto_srcs-additional_update_targets"></a>additional_update_targets |  A list of other `write_go_proto_srcs` targets whose configurations and runfiles should be transitively aggregated. Useful for creating a single root-level synchronization target.   |  `[]` |
| <a id="write_go_proto_srcs-diff_test"></a>diff_test |  If True, generates a corresponding `{name}_test` target.   |  `True` |
| <a id="write_go_proto_srcs-verbosity"></a>verbosity |  Verbosity level of the sync command outputs. One of `"full"`, `"short"`, or `"quiet"`.   |  `"full"` |
| <a id="write_go_proto_srcs-suggested_update_target"></a>suggested_update_target |  An optional suggested sync target path to print in the test failure error messages (e.g. `//:update_protos`).   |  `None` |
| <a id="write_go_proto_srcs-kwargs"></a>kwargs |  Common target attributes like `visibility`, `tags`, etc.   |  none |


<a id="collect_go_proto_srcs_aspect"></a>

## collect_go_proto_srcs_aspect

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "collect_go_proto_srcs_aspect")

collect_go_proto_srcs_aspect()
</pre>



**ASPECT ATTRIBUTES**


| Name | Type |
| :------------- | :------------- |
| deps| String |
| embed| String |


**ATTRIBUTES**



