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

write_go_proto_srcs(<a href="#write_go_proto_srcs-name">name</a>, <a href="#write_go_proto_srcs-srcs">srcs</a>, <a href="#write_go_proto_srcs-additional_update_targets">additional_update_targets</a>, <a href="#write_go_proto_srcs-kwargs">**kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="write_go_proto_srcs-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="write_go_proto_srcs-srcs"></a>srcs |  <p align="center"> - </p>   |  `[]` |
| <a id="write_go_proto_srcs-additional_update_targets"></a>additional_update_targets |  <p align="center"> - </p>   |  `[]` |
| <a id="write_go_proto_srcs-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


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



