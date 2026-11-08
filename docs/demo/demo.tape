# crewlead demo — re-render from the repo root with:
#   vhs docs/demo/demo.tape
# Every command and every line of output is real: it runs bin/crewlead
# against a throwaway Node project in /tmp/my-app (no network, no labels).

Output docs/demo/demo.gif

Set Shell "bash"
Set FontSize 16
Set Width 1320
Set Height 720
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Set CursorBlink false

Hide
Type `export PATH="$PWD/bin:$PATH" PS1='\[\e[1;34m\]my-app\[\e[0m\] $ ' && rm -rf /tmp/my-app && mkdir -p /tmp/my-app/src && cd /tmp/my-app && git init -q -b main && printf '{"name":"my-app","scripts":{"lint":"eslint .","test":"vitest run","build":"tsc -p ."}}\n' > package.json && echo 'export const hello = 1' > src/index.ts && git add -A && git commit -qm init && clear`
Enter
Sleep 1s
Show

Type "# put the flow into a repository (GitHub here; GitLab works too)"
Enter
Sleep 400ms
Type "crewlead init --platform github"
Sleep 300ms
Enter
Sleep 6s

Type "clear && crewlead check"
Sleep 300ms
Enter
Sleep 3s

Type "ls .agents/skills/ && grep -A5 '^commands:' .ai/project.yml"
Sleep 300ms
Enter
Sleep 4s

Type "sed -n 4,8p AGENTS.md"
Sleep 300ms
Enter
Sleep 4s

Type "# next: open the repo in Claude Code / Codex / Cursor, run project-setup, then file an issue"
Sleep 3s

Hide
Type "cd / && rm -rf /tmp/my-app"
Enter
