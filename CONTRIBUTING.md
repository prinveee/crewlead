# Contributing

Thanks for helping. crewlead is small on purpose — please keep it that way.

- **Open an issue first** for anything larger than a fix, so we can agree on
  the shape before you write it.
- **Run the tests:** `bash tests/run.sh` (needs git, bash, jq; no network).
  Add a test for any change to `bin/`, `lib/` or `core/setup/`.
- **Check the docs still resolve:** `bash core/check/check-drift.sh`.
- **Keep it agent-neutral.** Rules and skills must work for Claude Code, Codex
  and Cursor alike; put agent-specific notes behind `agents` in `.ai/project.yml`.
- **Plain words.** Write docs and agent instructions in short, plain sentences.
- Never commit secrets, customer names or personal paths, also not in examples.

By contributing you agree your work is released under the MIT License.
