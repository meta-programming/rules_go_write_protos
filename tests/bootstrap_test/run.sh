#!/usr/bin/env bash
set -euo pipefail

# Ensure no checked-in file exists
rm -f pkg/bootstrap/bootstrap.pb.go

echo "Step 1: Running check test (expected to fail)..."
if bazel test //pkg/bootstrap:update_protos_test > /tmp/test_fail.log 2>&1; then
    echo "ERROR: bazel test succeeded but was expected to fail because bootstrap.pb.go doesn't exist!"
    cat /tmp/test_fail.log
    exit 1
fi

echo "Verifying error output log..."
test_log="bazel-testlogs/pkg/bootstrap/update_protos_test/test.log"
if [ ! -f "$test_log" ]; then
    # Fallback to search for it in case the symlink is missing
    test_log=$(find bazel-out/ -name "test.log" | grep "update_protos_test" | head -n 1)
fi

if [ -z "$test_log" ] || [ ! -f "$test_log" ]; then
    echo "ERROR: Could not locate test log file!"
    cat /tmp/test_fail.log
    exit 1
fi

cat "$test_log"

if ! grep -q "source file does not exist in workspace: pkg/bootstrap/bootstrap.pb.go" "$test_log"; then
    echo "ERROR: Expected drift test failure message not found in logs!"
    exit 1
fi
echo "Drift test failed as expected."

echo "Step 2: Running sync target (expected to create bootstrap.pb.go)..."
bazel run //pkg/bootstrap:update_protos

if [ ! -f pkg/bootstrap/bootstrap.pb.go ]; then
    echo "ERROR: bootstrap.pb.go was not created by the sync target!"
    exit 1
fi
echo "bootstrap.pb.go successfully created."

echo "Step 3: Running check test again (expected to pass)..."
bazel test //pkg/bootstrap:update_protos_test

echo "Cleaning up generated workspace files..."
rm -f pkg/bootstrap/bootstrap.pb.go

echo "SUCCESS: Bootstrap lifecycle integration test passed!"
