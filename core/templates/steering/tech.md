# Tech

<!-- Steering: always loaded into AGENTS.md. One page at most. Summarise the
     architecture decisions agents must respect; link the full ADRs. -->

## Stack
| Layer | Choice |
|---|---|

## Decisions agents must respect
<!-- Technical invariants, each with the ADR/decision it comes from. -->
1. …

## Commands
Exact commands live in `.ai/project.yml` → `commands`. Agents run only
`commands.test_local` on a developer machine; CI runs `commands.test_full`.

## Local machine
<!-- Shared resources (a shared dev or staging database?), what never to run, credentials. -->

## Deploy
<!-- What deploys, when, and what agents must never run. -->

## Deeper docs
- …
