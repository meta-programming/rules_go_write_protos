<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="check_go_proto_srcs_test"></a>

## check_go_proto_srcs_test

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "check_go_proto_srcs_test")

check_go_proto_srcs_test(<a href="#check_go_proto_srcs_test-name">name</a>, <a href="#check_go_proto_srcs_test-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="check_go_proto_srcs_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="check_go_proto_srcs_test-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="write_go_proto_srcs"></a>

## write_go_proto_srcs

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "write_go_proto_srcs")

write_go_proto_srcs(<a href="#write_go_proto_srcs-name">name</a>, <a href="#write_go_proto_srcs-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="write_go_proto_srcs-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="write_go_proto_srcs-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


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


<a id="write_go_proto_sources"></a>

## write_go_proto_sources

<pre>
load("@rules_go_write_protos//rules:defs.bzl", "write_go_proto_sources")

write_go_proto_sources(<a href="#write_go_proto_sources-name">name</a>, <a href="#write_go_proto_sources-srcs">srcs</a>, <a href="#write_go_proto_sources-kwargs">**kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="write_go_proto_sources-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="write_go_proto_sources-srcs"></a>srcs |  <p align="center"> - </p>   |  none |
| <a id="write_go_proto_sources-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


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



