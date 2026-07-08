#!/usr/bin/env bash
set -euo pipefail

# Ensure custom directories are clean
rm -rf pkg/foo/custom_out pkg/foo/custom_map

echo "Step 1: Running out_dir check test (expected to fail)..."
if bazel test //pkg/foo:update_protos_out_dir_test > /tmp/test_out_dir_fail.log 2>&1; then
    echo "ERROR: out_dir test succeeded but was expected to fail because files don't exist!"
    cat /tmp/test_out_dir_fail.log
    exit 1
fi
echo "out_dir check test failed as expected."

echo "Step 2: Syncing out_dir target..."
bazel run //pkg/foo:update_protos_out_dir

if [ ! -f pkg/foo/custom_out/foo.pb.go ]; then
    echo "ERROR: pkg/foo/custom_out/foo.pb.go was not created!"
    exit 1
fi
echo "pkg/foo/custom_out/foo.pb.go successfully created."

echo "Step 3: Running out_dir check test again (expected to pass)..."
bazel test //pkg/foo:update_protos_out_dir_test


echo "Step 4: Running out_dir_map check test (expected to fail)..."
if bazel test //pkg/foo:update_protos_out_dir_map_test > /tmp/test_out_dir_map_fail.log 2>&1; then
    echo "ERROR: out_dir_map test succeeded but was expected to fail because files don't exist!"
    cat /tmp/test_out_dir_map_fail.log
    exit 1
fi
echo "out_dir_map check test failed as expected."

echo "Step 5: Syncing out_dir_map target..."
bazel run //pkg/foo:update_protos_out_dir_map

if [ ! -f pkg/foo/custom_map/foo.pb.go ]; then
    echo "ERROR: pkg/foo/custom_map/foo.pb.go was not created!"
    exit 1
fi
echo "pkg/foo/custom_map/foo.pb.go successfully created."

echo "Step 6: Running out_dir_map check test again (expected to pass)..."
bazel test //pkg/foo:update_protos_out_dir_map_test


echo "Cleaning up generated custom location files..."
rm -rf pkg/foo/custom_out pkg/foo/custom_map

echo "SUCCESS: Custom output locations integration test passed!"
