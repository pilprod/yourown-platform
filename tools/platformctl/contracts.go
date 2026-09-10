package main

import (
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/pilprod/yourown-platform/internal/contracts"
)

func contractCommand(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		return 2
	}
	flags := flag.NewFlagSet(args[0], flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	file := flags.String("file", "", "reference-only contract document")
	snapshot := flags.String("snapshot", "", "private JSON snapshot; verify-config only")
	if flags.Parse(args[1:]) != nil || flags.NArg() != 0 || *file == "" || args[0] != "validate" && args[0] != "verify-config" || args[0] == "validate" && *snapshot != "" || args[0] == "verify-config" && *snapshot == "" {
		fmt.Fprintln(stderr, "usage: platformctl validate --file <document> | verify-config --file <environment> --snapshot <private-json>")
		return 2
	}
	f, err := os.Open(*file)
	if err != nil {
		fmt.Fprintln(stderr, "cannot open contract document")
		return 2
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, contracts.MaxBytes+1))
	if err != nil {
		fmt.Fprintln(stderr, "cannot read contract document")
		return 2
	}
	if args[0] == "validate" {
		_, err = contracts.Validate(data)
	} else {
		s, e := os.Open(*snapshot)
		if e != nil {
			fmt.Fprintln(stderr, "cannot open private snapshot")
			return 2
		}
		defer s.Close()
		err = contracts.VerifySnapshot(data, s)
	}
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	fmt.Fprintln(stdout, "Validation passed. No references resolved and no cloud operation performed.")
	return 0
}
