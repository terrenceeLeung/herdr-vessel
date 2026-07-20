---
name: grill-product-goal
description: Relentlessly explore a product idea with the Captain until both sides share an understanding of the goal, observable behavior, boundaries, failures, and success. Use when product intent is still unclear; investigate discoverable facts, ask one consequential question at a time, and leave software design to the Chief Engineer.
license: MIT
disable-model-invocation: true
metadata:
  source: https://github.com/mattpocock/skills
  adapted-commit: e9fcdf95b402d360f90f1db8d776d5dd450f9234
---

# Grill the Product Goal

Interview the Captain relentlessly about the product idea until you reach a shared understanding. Relentless means following consequential uncertainty to its end, not exhausting a generic questionnaire.

Walk down each consequential branch of the product decision tree, resolving dependencies between decisions one by one. The aim is a coherent goal, not a long document.

## Facts and Decisions

Read repository guidance and existing product documents. Inspect current user-visible behavior when it helps distinguish present fact from desired future.

If a fact can be found in the repository, tools, or authoritative platform material, look it up instead of asking the Captain. Product decisions are the Captain's: put each consequential one to them and wait for the answer.

For each question, provide a recommended answer when evidence or a credible default exists, together with the important product trade-off. For pure preference, offer concrete options without inventing an objectively correct answer.

Ask one question at a time and wait for feedback. Prefer concrete scenarios that expose rule conflicts, hidden actors, boundary cases, or failure experience.

Translate technical proposals into observable consequences. If an idea has no external consequence, retain it only as non-binding input for the Chief Engineer rather than asking the Captain to design software internals.

When real product-domain language is resolved, read `../../../shared/context-format.md` and update `CONTEXT.md` lazily. The glossary records language, not requirements or architecture.

Do not advance to the Product Contract, Engineering Design, or implementation until the Captain confirms that shared understanding has been reached. Then summarize the goal, observable contract, non-goals, acceptance examples, open product questions, and any non-binding engineering suggestions for `to-product-spec`.
