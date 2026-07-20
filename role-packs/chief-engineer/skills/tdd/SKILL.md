---
name: tdd
description: Drive implementation or repair through behavior-first red/green cycles at a stable public seam. Use when a meaningful behavior test can be written; choose internal test mechanics autonomously, mock only real external boundaries, and complete one vertical tracer bullet per cycle.
license: MIT
metadata:
  source: https://github.com/mattpocock/skills
  adapted-commit: e9fcdf95b402d360f90f1db8d776d5dd450f9234
---

# Test-Driven Development

Tests protect externally meaningful behavior while leaving internal implementation free to change.

Use the stable public seam named by the Engineering Design or already established by the repository. Prefer integration-style tests through real public interfaces. Mock external systems, time, randomness, or expensive infrastructure at their boundaries; do not mock internal collaborators merely to observe calls.

1. Select one concrete acceptance example.
2. Write a test that fails for the expected reason.
3. Implement only enough behavior to make it pass.
4. Run the narrow test, then clean up understood code without changing behavior.
5. Continue with the next vertical example.

Expected results must come from the Product Contract, a derived example, or another independent source of truth. Do not reproduce the implementation algorithm inside the test.

Avoid writing every imagined test before implementation, asserting private methods, verifying internal call counts, or approving snapshots whose difference cannot be explained.
