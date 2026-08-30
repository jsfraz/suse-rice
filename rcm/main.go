package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		cmd := HelpCommand{}
		if err := cmd.Execute(nil); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}

	command := os.Args[1]
	args := os.Args[2:]

	var cmd Command
	switch command {
	case "get":
		cmd = GetCommand{}
	case "set":
		cmd = SetCommand{}
	case "help":
		cmd = HelpCommand{}
	default:
		fmt.Fprintf(os.Stderr, "Error: unknown command: %s\n", command)
		fmt.Fprintf(os.Stderr, "Run 'rcm help' for usage information.\n")
		os.Exit(1)
	}

	if err := cmd.Execute(args); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
