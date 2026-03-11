package main

import (
	"fmt"
	"os"
)

func main() {
	// Verify non-root execution
	uid := os.Getuid()
	if uid == 0 {
		fmt.Fprintf(os.Stderr, "Container must not run as root (got uid=%d)\n", uid)
		os.Exit(1)
	}

	fmt.Printf("Running as uid: %d\n", uid)
	fmt.Println("All smoke test assertions passed.")
}
