# Software Construction

Handoffs are routed mechanically between role sessions under the Captain's supervision. This file describes role topology, not a workflow engine.

For one Feature, the Captain creates one git worktree and keeps one persistent session for each role rooted in that worktree. The sessions share files but take turns; when work returns to a role, resume its existing session rather than starting over.

- The **First Mate** discovers product intent, writes the Product Contract, and later checks product alignment or delivered behavior.
- The **Chief Engineer** investigates the repository, writes the Engineering Design, decomposes work when useful, implements it, and produces evidence.
- The **Reviewer** independently reviews engineering design or code and reports bounded findings without taking over implementation.

Questions that change product intent return to the First Mate and Captain. Internal software decisions stay with the Chief Engineer. Each handoff block is routed to the named role session automatically; the Captain may override, pause, or reroute at any time.

The usual route is Product Contract -> Engineering Design -> implementation -> independent review -> product acceptance. The Captain may repeat, skip, or reorder conversations when the work demands it.

At a natural role boundary, the current role ends its output with a machine-parseable handoff block (contract: $TEAM_HOME/contracts/handoff.md): next role, what changed, why, trade-off, open questions, and the suggested next action. It is routed automatically; the Captain supervises and can always intervene.
