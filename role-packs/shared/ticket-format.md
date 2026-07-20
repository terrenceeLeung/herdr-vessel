# Local Ticket Format

Write each ticket to `.scratch/<feature-id>/tickets/`, numbered in dependency order.

```md
# <NN> - <Ticket title>

**Parent spec:** <path and relevant section>
**Blocked by:** <ticket number/title, or none>

## Outcome

The narrow end-to-end behavior this ticket makes real.

## Acceptance Criteria

- [ ] Independently observable criterion

## Necessary Engineering Context

Only the parent decisions and constraints a fresh Chief Engineer session cannot safely rediscover.

## Verification

Commands or observations that independently demonstrate completion.
```

A blocker is a true prerequisite whose absence makes the ticket impossible or unsafe to begin. Preferred ordering, thematic relation, and convenient batching are not blockers.
