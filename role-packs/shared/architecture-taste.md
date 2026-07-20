# Architecture Taste

Use these as design questions, not a compliance checklist. Seek the smallest structure that handles the Feature's real change pressure.

- **Clean architecture / ports and adapters:** keep policy independent of volatile frameworks or external systems where a real boundary exists; do not invent a port for every function.
- **Domain-driven design:** let stable product language shape core concepts; do not manufacture bounded contexts or value objects without domain pressure.
- **Data-intensive systems:** when data matters, make ownership, invariants, consistency, ordering, concurrency, retry, and lifecycle explicit.
- **Resilience:** at external boundaries consider timeout, partial failure, idempotency, recovery, observability, and operational limits.
- **Refactoring:** optimize for understandable change and remove speculative generality.

Useful questions include: What is policy and what is replaceable mechanism? Where are the real external boundaries? Who owns each piece of state? What happens under duplication, delay, reordering, concurrency, partial completion, or retry? Which choices create public or hard-to-reverse commitments? What can an operator observe? Which stable public seam can prove behavior without coupling tests to internals?

A simple modular design is enough when it answers the relevant questions. Add architectural machinery only when it buys concrete isolation, correctness, replaceability, or operability.
