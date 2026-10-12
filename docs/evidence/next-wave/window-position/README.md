# Window positioning evidence

This directory preserves three exact reports for DJI Studio 1.0.0.30839.
Sol authored the analysis. An independent Sol High reviewer approved it in
comms 1553. Astra High verified the milestone in comms 1580.
The manifest gives each report hash and its original workspace path.

The approved scope covers the static screen selector, intersection predicate,
and position reset routines. The selector uses a strict signed score comparison.
Ties keep the earlier selection. Empty and nonempty screen lists have different
fallback branches. Reset arithmetic has explicit stability and overflow limits.

This approval does not cover a native adapter, platform behavior, runtime movement,
or comparison with Windows. The Qt geometry packets have separate review gates.
Do not infer full UI behavior from these reports.

The full binary, RAE evidence, byte captures, and local review manifests are not
included. Paths in the preserved reports refer to the maintainer workspace.
Request an artifact by its exact path and hash before repeating analysis.
Evidence IDs identify archived records. They do not provide public downloads.
