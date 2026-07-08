// Package main is a developer tool to copy and verify generated Go protobuf files
// in the workspace source tree.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

type FileMapping struct {
	Src  string `json:"src"`  // Path relative to runfiles
	Dest string `json:"dest"` // Path relative to workspace root
}

type Config struct {
	Mode  string        `json:"mode"` // "sync" or "check"
	Files []FileMapping `json:"files"`
}

func main() {
	// The configuration file is expected to be named [exec_name].json in runfiles.
	execName := filepath.Base(os.Args[0])
	configRunfilePath := fmt.Sprintf("_main/%s.json", execName)

	rpath, err := runfiles.Rlocation(configRunfilePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to locate configuration runfile %s: %v\n", configRunfilePath, err)
		os.Exit(1)
	}

	configBytes, err := os.ReadFile(rpath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read configuration: %v\n", err)
		os.Exit(1)
	}

	var config Config
	if err := json.Unmarshal(configBytes, &config); err != nil {
		fmt.Fprintf(os.Stderr, "invalid configuration format: %v\n", err)
		os.Exit(1)
	}

	if config.Mode == "sync" {
		err = runSync(config.Files)
	} else {
		err = runCheck(config.Files)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

func runSync(files []FileMapping) error {
	workspaceDir := os.Getenv("BUILD_WORKSPACE_DIRECTORY")
	if workspaceDir == "" {
		return fmt.Errorf("BUILD_WORKSPACE_DIRECTORY is not set; must run via 'bazel run'")
	}

	for _, fm := range files {
		srcPath, err := runfiles.Rlocation(fm.Src)
		if err != nil {
			return fmt.Errorf("failed to locate runfile %s: %w", fm.Src, err)
		}
		destPath := filepath.Join(workspaceDir, fm.Dest)

		if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
			return fmt.Errorf("failed to create directory for %s: %w", fm.Dest, err)
		}

		if err := copyFile(srcPath, destPath); err != nil {
			return fmt.Errorf("failed to copy %s to %s: %w", fm.Src, fm.Dest, err)
		}
		
		// Ensure the file is writable.
		if err := os.Chmod(destPath, 0644); err != nil {
			return fmt.Errorf("failed to set write permissions on %s: %w", fm.Dest, err)
		}
		fmt.Printf("Updated: %s\n", fm.Dest)
	}
	return nil
}

func runCheck(files []FileMapping) error {
	// For testing, locate workspace root by resolving the MODULE.bazel symlink in runfiles.
	markerPath, err := runfiles.Rlocation("_main/MODULE.bazel")
	if err != nil {
		return fmt.Errorf("failed to locate MODULE.bazel: %w", err)
	}

	realMarkerPath, err := filepath.EvalSymlinks(markerPath)
	if err != nil {
		return fmt.Errorf("failed to resolve MODULE.bazel symlink: %w", err)
	}
	workspaceRoot := filepath.Dir(realMarkerPath)

	failed := false
	for _, fm := range files {
		srcPath, err := runfiles.Rlocation(fm.Src)
		if err != nil {
			return fmt.Errorf("failed to locate runfile %s: %w", fm.Src, err)
		}
		destPath := filepath.Join(workspaceRoot, fm.Dest)

		if _, err := os.Stat(destPath); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "source file does not exist in workspace: %s\n", fm.Dest)
			failed = true
			continue
		}

		match, err := filesAreEqual(srcPath, destPath)
		if err != nil {
			return err
		}
		if !match {
			fmt.Fprintf(os.Stderr, "source file out of sync: %s\n", fm.Dest)
			failed = true
		}
	}

	if failed {
		return fmt.Errorf("verification failed; run the update target to sync generated files")
	}
	fmt.Println("All generated Go proto files are up to date!")
	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func filesAreEqual(path1, path2 string) (bool, error) {
	f1, err := os.ReadFile(path1)
	if err != nil {
		return false, err
	}
	f2, err := os.ReadFile(path2)
	if err != nil {
		return false, err
	}
	return bytes.Equal(f1, f2), nil
}
