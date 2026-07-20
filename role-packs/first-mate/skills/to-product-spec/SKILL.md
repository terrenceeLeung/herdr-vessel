---
name: to-product-spec
description: Crystallize a confirmed product discussion into the Product Contract block of a Feature under docs/features. Use after product grilling has reached shared understanding; do not reopen the interview or choose software internals.
license: MIT
disable-model-invocation: true
metadata:
  source: https://github.com/mattpocock/skills
  adapted-commit: e9fcdf95b402d360f90f1db8d776d5dd450f9234
---

# Write the Product Spec

Turn the shared understanding into a product-facing target-state proposal. This is crystallization, not another interview.

1. Read the discussion, repository guidance, and relevant product documents, glossary, and user-visible evidence.
2. Read `../../../shared/feature-spec-format.md`.
3. Use the path supplied by the Captain, update an obvious matching Feature, or allocate the next `docs/features/F<NNN>-<slug>.md`.
4. Write the Product Contract and leave the Engineering Design pending.

Describe the problem, desired outcome, people, representative scenarios, observable rules, failure and recovery experience, acceptance examples, non-goals, and genuinely open product questions. Use the Captain's language. Preserve externally meaningful constraints without prescribing modules, schemas, libraries, process topology, or test seams.

Prefer a few discriminating scenarios over exhaustive user stories. Keep uncertainty visible rather than fabricating completeness.

Report the Feature path, the product choices it now captures, and any questions still requiring the Captain. List excluded implementation ideas separately as non-binding input for the Chief Engineer.
