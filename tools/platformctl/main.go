package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/pilprod/yourown-platform/internal/repository"
)

func main() { os.Exit(run(os.Args[1:])) }

func run(args []string) int {
	if len(args) > 0 && (args[0] == "validate" || args[0] == "verify-config") {
		return contractCommand(args, os.Stdout, os.Stderr)
	}
	if len(args) == 0 || args[0] != "scan" {
		fmt.Fprintln(os.Stderr, "usage: platformctl scan --root <git-worktree> | validate --file <document> | verify-config --file <environment> --snapshot <private-json>")
		return 2
	}
	flags := flag.NewFlagSet("scan", flag.ContinueOnError)
	root := flags.String("root", ".", "Git worktree to scan; only tracked working-tree files are checked")
	if err := flags.Parse(args[1:]); err != nil || flags.NArg() != 0 {
		return 2
	}
	findings, err := repository.Scan(*root)
	if err != nil {
		fmt.Fprintln(os.Stderr, "scan could not complete; check the Git worktree and file access")
		return 2
	}
	for _, f := range findings {
		fmt.Fprintf(os.Stderr, "%q:%d: %s\n", f.Path, f.Line, f.Rule)
	}
	if len(findings) != 0 {
		return 1
	}
	fmt.Println("Tracked working-tree scan passed. This is not a complete secret or history audit.")
	return 0
}
