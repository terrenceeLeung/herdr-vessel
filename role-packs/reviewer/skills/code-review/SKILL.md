---
name: code-review
description: Independently review the Chief Engineer's complete change set against repository standards and its source Feature or ticket. Use after implementation; inspect all worktree state, separate engineering findings from spec findings, and do not implement fixes.
license: MIT
disable-model-invocation: true
metadata:
  source: https://github.com/mattpocock/skills
  adapted-commit: e9fcdf95b402d360f90f1db8d776d5dd450f9234
---

# Code Review

Review the complete change on two independent axes so clean code cannot hide the wrong product and spec compliance cannot hide unsafe engineering.

## Evidence

1. Read the supplied Feature or ticket and follow any parent reference.
2. Determine the relevant comparison point; when none is supplied, use the obvious merge base and include current worktree changes.
3. Inspect committed, staged, unstaged, and untracked work in scope.
4. Read applicable repository guidance, configuration, glossary, ADRs, and tests. Read `../../../shared/architecture-taste.md` when architecture is relevant.

## Engineering Standards

Assess correctness, maintainability, dependency direction, domain language, boundary leaks, state and failure handling, security, compatibility, test quality, and speculative generality. Repository standards outrank generic taste; do not report issues already enforced reliably by tooling.

For each finding, give severity (`blocking`, `important`, or `suggestion`), location, evidence, consequence, and a useful boundary for the fix.

## Spec Alignment

Use the Product Contract, Engineering Design, ticket outcome, and acceptance criteria to find missing or incorrect behavior, unrequested scope, and missing evidence. Cite the source requirement. Keep style issues on the engineering axis.

## Report

Use `## Engineering Standards`, `## Spec Alignment`, and `## Review Summary`. Count blocking findings separately on each axis and say explicitly when none exist. Return fixes to the Chief Engineer; do not implement them.
