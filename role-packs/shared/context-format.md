# CONTEXT.md Format

`CONTEXT.md` is the product-domain glossary, not a requirements or architecture document. Create it lazily when the first real domain term is resolved.

```md
# <Context name>

<One or two sentences describing what this context is and why it exists.>

## Language

**Order**: A request from a customer for goods to be delivered.

_Avoid_: Purchase, transaction

**Invoice**: A request for payment sent after delivery.

_Avoid_: Bill, payment request
```

- Be opinionated. Pick one word for a concept and list competing terms under `_Avoid_`.
- Keep definitions to one or two sentences. Define what the concept is, not every behavior it has.
- Include language specific to the product context. General programming concepts do not belong.
- Add sections only when natural clusters emerge.

Most repositories need one root `CONTEXT.md`. If multiple domain contexts already exist, follow the repository's existing context map and place the term where it belongs; ask only when the correct ownership is genuinely ambiguous.
