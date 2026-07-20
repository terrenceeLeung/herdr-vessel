---
name: to-engineering-spec
description: Crystallize the Chief Engineer's investigation into the Engineering Design block of the existing Feature. Use after software-design grilling; preserve the Product Contract, choose internals autonomously, and record only rationale future work cannot safely rediscover.
license: MIT
disable-model-invocation: true
metadata:
  source: https://github.com/mattpocock/skills
  adapted-commit: e9fcdf95b402d360f90f1db8d776d5dd450f9234
---

# Write the Engineering Spec

Produce the smallest implementable Engineering Design that satisfies the Product Contract.

1. Read the complete Feature and the repository evidence used during design investigation.
2. Read `../../../shared/feature-spec-format.md` and `../../../shared/architecture-taste.md`.
3. Preserve the Product Contract and replace the pending Engineering Design with only the sections this Feature needs.

Record decisions implementation cannot safely re-derive: logical boundaries and dependency direction; contracts or data shapes depended on by callers; relevant state ownership and invariants; external effects, failure, concurrency, timeout, retry, and recovery semantics; trust, compatibility, operations, and stable behavior seams; important alternatives, assumptions, and risks.

Describe logical components rather than a file-by-file construction script. Include exact types, state machines, or schemas only when they communicate a decision more clearly than prose.

Create an ADR only when the decision is hard to reverse, surprising without context, and the result of a real trade-off. When all three hold, read `../../../shared/adr-format.md` and write the minimal useful ADR. Otherwise keep any necessary rationale in the Engineering Design.

If engineering evidence still exposes a product question, report it rather than hiding a product decision in the design. Otherwise report the updated Feature path and the important engineering choices.
