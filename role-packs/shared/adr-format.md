# ADR Format

ADRs live in `docs/adr/` and use sequential names such as `0001-slug.md`. Create the directory lazily, only when the first ADR is justified.

```md
# <Short title of the decision>

<One to three sentences: the context, what was decided, and why.>
```

That can be the whole ADR. The value is recording that a decision was made and why, not filling out sections.

Add optional status, considered alternatives, or consequences only when they help a future reader.

Offer an ADR only when all three conditions hold:

1. The decision is hard to reverse.
2. The result would be surprising without its context.
3. It reflects a real trade-off between plausible alternatives.

Easy-to-reverse choices, obvious choices, and choices with no real alternative belong in code or the Engineering Design, not an ADR.
