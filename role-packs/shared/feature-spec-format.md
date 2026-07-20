# Feature Document Format

The First Mate and Chief Engineer collaborate through one target-state document. The First Mate writes the Product Contract; the Chief Engineer preserves it and adds the Engineering Design. A reviewer reads both blocks but does not rewrite them.

Scale the document to the Feature. Omit irrelevant sections instead of filling a form.

```md
---
feature_id: F001
created: YYYY-MM-DD
---

# <Feature title>

## Product Contract

### Problem

### Desired Outcome

### People and Scenarios

### Observable Behavior

### Product Rules and Constraints

### Failure and Recovery Experience

### Acceptance Examples

### Non-goals

### Open Product Questions

## Engineering Design

> Pending Chief Engineer design.
```

When adding the Engineering Design, choose only the sections the Feature needs:

```md
### Design Summary
### Boundaries and Responsibilities
### Contracts and Data Shapes
### State and Data Lifecycle
### Failure, Concurrency, and Recovery
### External Dependencies, Security, and Operations
### Test Strategy and Seams
### Engineering Decisions
### Risks and Assumptions
### ADR
### Product Questions
```

The document describes the proposed target state, not workflow history. Human acceptance and routing stay in the conversation or handoff rather than a status field.

Lower-level documents do not change upper-level intent: the Product Contract governs observable behavior, the Engineering Design governs internal choices that satisfy it, and a ticket only narrows delivery scope.
