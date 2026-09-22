package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/pilprod/yourown-platform/internal/agentcontext"
	"github.com/pilprod/yourown-platform/internal/repository"
)

func main() { os.Exit(run(os.Args[1:])) }

func run(args []string) int { return runWithIO(args, os.Stdout, os.Stderr) }

func runWithIO(args []string, stdout, stderr io.Writer) int {
	if len(args) != 0 {
		switch args[0] {
		case "scan":
			return scan(args[1:], stdout, stderr)
		case "context":
			return context(args[1:], stdout, stderr)
		}
	}
	fmt.Fprintln(stderr, "usage: platformctl scan --root <git-worktree> | platformctl context --root <repository> --topic <topic>")
	return 2
}

func scan(args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("scan", flag.ContinueOnError)
	flags.SetOutput(stderr)
	root := flags.String("root", ".", "Git worktree to scan; only tracked working-tree files are checked")
	if err := flags.Parse(args); err != nil || flags.NArg() != 0 {
		return 2
	}
	findings, err := repository.Scan(*root)
	if err != nil {
		fmt.Fprintln(stderr, "scan could not complete; check the Git worktree and file access")
		return 2
	}
	for _, f := range findings {
		fmt.Fprintf(stderr, "%q:%d: %s\n", f.Path, f.Line, f.Rule)
	}
	if len(findings) != 0 {
		return 1
	}
	fmt.Fprintln(stdout, "Tracked working-tree scan passed. This is not a complete secret or history audit.")
	return 0
}

func context(args []string, stdout, stderr io.Writer) int {
	flags := flag.NewFlagSet("context", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	root := flags.String("root", ".", "Repository containing rag/manifest.json")
	topic := flags.String("topic", "general", "Explicit context topic from the manifest")
	if err := flags.Parse(args); err != nil || flags.NArg() != 0 {
		fmt.Fprintln(stderr, "usage: platformctl context --root <repository> --topic <topic>")
		return 2
	}
	bundle, err := agentcontext.Load(*root, *topic)
	if err != nil {
		fmt.Fprintln(stderr, "context could not complete; check the manifest, selected topic and public source files")
		return 2
	}
	data, err := json.Marshal(bundle)
	if err != nil {
		fmt.Fprintln(stderr, "context could not be encoded")
		return 2
	}
	if _, err := fmt.Fprintln(stdout, string(data)); err != nil {
		fmt.Fprintln(stderr, "context could not be written")
		return 2
	}
	return 0
}
