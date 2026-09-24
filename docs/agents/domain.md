# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

Layout: **single-context**. Official decisions live in `docs/decisions.md` (D-xx entries), not `docs/adr/`.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: the domain glossary.
- **`docs/decisions.md`**: read the D-xx entries that touch the area you're about to work in, plus the open-decisions table at the end.
- **`docs/PRD.md`** and **`docs/roadmap.md`** for feature IDs (F-x.y) and phase scope.

If any of these files don't exist, **proceed silently**.

## File structure

```
/
├── CONTEXT.md
├── docs/
│   ├── decisions.md    ← D-01, D-02, ... plus open decisions
│   ├── PRD.md
│   └── roadmap.md
└── src/
```

## Changing these files

`CONTEXT.md` and `docs/decisions.md` change only with the CTO's explicit approval. Where a skill (e.g. `/domain-modeling`) would write an ADR under `docs/adr/`, propose a new D-xx entry in `docs/decisions.md` instead, using the existing format (Status, Keputusan, Alasan, Konsekuensi), and wait for approval before writing.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag decision conflicts

If your output contradicts an existing decision, surface it explicitly rather than silently overriding:

> _Contradicts D-10 (credit rules in Postgres), but worth reopening because…_
