---
name: to-tickets
description: Split a Feature into tracer-bullet tickets sized for fresh implementation contexts, with only true prerequisite dependencies. Use when the Feature is too large for one context; self-check the decomposition and write one local file per vertical slice.
license: MIT
disable-model-invocation: true
metadata:
  source: https://github.com/mattpocock/skills
  adapted-commit: e9fcdf95b402d360f90f1db8d776d5dd450f9234
---

# Write Tickets

Tickets package work for fresh Chief Engineer contexts. They narrow the Feature; they do not change it.

1. Read the complete Feature and enough current code to estimate the real integration path.
2. Read `../../../shared/ticket-format.md`.
3. Design vertical slices whose behavior can be proven independently and whose work fits a fresh context.
4. Add a dependency only when the earlier ticket is a true prerequisite.
5. Check for horizontal layers, invented scope, duplicated parent prose, false dependencies, and oversized tickets.
6. Write one file per ticket under `.scratch/<feature-id>/tickets/`, numbered in dependency order.

If the complete Feature already fits one context, do not manufacture multiple tickets. A single ticket is enough, and direct implementation may be even clearer. Broad mechanical migrations may use expand-migrate-contract when vertical slices cannot keep the repository valid.

Each ticket references its parent, names an end-to-end outcome and concrete acceptance criteria, carries only engineering context a fresh session cannot safely rediscover, and provides independent verification.

A ticket is the default implementation context. If meaningful sequencing decisions still cannot be derived safely, split the ticket or write a temporary plan that resolves those decisions; never create a plan as ritual or restate the ticket. Report the dependency graph and which tickets can start immediately.
