---
name: grill-software-design
description: Investigate the repository and stress-test a settled Product Contract until a feasible software direction is clear. Use before writing Engineering Design; resolve engineering questions autonomously and ask the Captain only when evidence exposes a product decision.
license: MIT
disable-model-invocation: true
metadata:
  source: local
  informed-by: Matt Pocock's grilling and Tutu Vessel F027 Phase C
---

# Grill the Software Design

Interrogate the repository and the design more than the Captain. The Chief Engineer should decide software internals while making genuine product consequences visible.

Read the complete Feature, repository guidance, relevant glossary and ADRs, code, tests, dependencies, configuration, and `../../../shared/architecture-taste.md`. Consult authoritative upstream material when platform behavior affects feasibility.

Trace the boundaries, state ownership, external effects, failure paths, compatibility commitments, and useful behavior seams relevant to this Feature. Resolve dependencies between engineering decisions in an order that keeps later choices informed.

Investigate repository and platform facts directly. Decide ordinary reversible choices and durable internal architecture choices inside the Product Contract. Retain important rationale without turning the investigation into a transcript.

Ask the Captain only when reasonable designs imply materially different observable behavior, the Product Contract must change, the desired outcome is infeasible or seriously degraded, or an engineering choice creates a hard-to-reverse external policy not governed by the contract.

When product authority is needed, explain the evidence, user-visible consequence, recommended answer, and trade-off in product language. Ask one question at a time. A new product decision belongs in the revised Product Contract, not only in engineering notes.

Finish with the proposed direction, important decisions, risks, and possible ADR candidates. Preserve both the Product Contract and implementation code; `to-engineering-spec` performs the write.
