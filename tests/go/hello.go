package main

import (
	"fmt"
	"os"
	"runtime"
)

func main() {
	// Verify non-root execution
	uid := os.Getuid()
	if uid == 0 {
		fmt.Fprintf(os.Stderr, "Container must not run as root (got uid=%d)\n", uid)
		os.Exit(1)
	}

	// Verify Go version matches expected (if provided via env)
	expected := os.Getenv("EXPECTED_VERSION")
	if expected != "" {
		actual := runtime.Version()
		expectedFull := "go" + expected
		if actual != expectedFull {
			fmt.Fprintf(os.Stderr, "Version mismatch: expected %s, got %s\n", expectedFull, actual)
			os.Exit(1)
		}
	}

	fmt.Printf("Go version: %s\n", runtime.Version())
	fmt.Printf("Running as uid: %d\n", uid)
	fmt.Println("All smoke test assertions passed.")
}
