# Model authors and contributors

This record identifies verified model contributions and keeps authorship separate
from independent review. Credits apply to the stated work, not full application parity.
The GitHub maintainer is [pastawithpesto](https://github.com/pastawithpesto).

| Model | Verified role | Evidence |
| --- | --- | --- |
| GPT-6.1 Sol | Code author for the PR acceptance worker; separate Sol instances independently reviewed it | [PR 4](https://github.com/pastawithpesto/dji-studio-omarchy/pull/4), author record 1468, independent review 1474 |
| GPT-6 Luna, High | Resource recovery and packaging; corrected layout, startup, registration, and SDK provenance records | [PR 1](https://github.com/pastawithpesto/dji-studio-omarchy/pull/1), source `632efe2a3e63296f30a980606d424284d8876a3c`; [PR 3](https://github.com/pastawithpesto/dji-studio-omarchy/pull/3#issuecomment-6106354815) |
| GPT-6 Astra, High | Review report author and independent milestone verifier | [PR 4 review record](https://github.com/pastawithpesto/dji-studio-omarchy/pull/4#issuecomment-6106482696), milestone 1476; original UI milestones 1448 to 1450 |
| GLM-5.3-Flash, High | Resource SDK static analysis and correction reports through ZCode with saved Ghidra/RAE evidence | Resource SDK v3 record 1417, independent review 1431, combined provenance approval 1446 |

Recovered DJI resource content retains its original provenance. Luna's credit is
for recovery, packaging, and analysis, not original authorship of those assets.
Astra's credited work is review and verification, not application code authorship.
Codex root coordinates integration and authored this attribution document; its
exact model identity is not established by the cited records.

The numbered records are in the addressed local coordination archive. Some full
analysis artifacts are not distributed in this source repository. See
[research instructions](docs/RESEARCH.md) to request an artifact by path and hash.
The GLM packet is `glm-review/next-wave/resource-sdk-correction-v3`; its controlling
history erratum is `luna-review/luna-b-1/next-wave/sdk-history-erratum`. Approval
applies to their combined reading and does not establish full SDK behavior.

## Historical Git identity correction

The Sol-authored PR 4 source commits `2b30764`, `bd64a43`, `0900888`, and `8162cd2`
inherited a shared Git identity named `Luna B-2 Resource Author`. Preserved agent
records establish GPT-6.1 Sol as their actual author. The reservation commit
`d38f9f7` was created by the Codex coordinator. Existing reviewed hashes remain
unchanged; the PR and merge message record the correction. A shared Git display
name alone is not reliable model attribution.

## Future contributions

Use an explicit per-commit identity rather than inherited shared Git configuration.
Record only models that actually contributed. Preserve human authors and distinguish
independent reviewers. Add applicable trailers, for example:

```text
Model-authored-by: GPT-6.1 Sol (High, Standard)
Model-reviewed-by: GPT-6.1 Sol (independent High, Standard worker)
Model-verified-by: GPT-6 Astra (High, Standard)
```

For model-assisted human work, describe the model's actual role in the PR. Do not
credit a configured, unavailable, or nonproductive model as an author.
These model trailers are descriptive metadata, not GitHub account identities.
Use `Co-authored-by: Name <email>` for account-linked credit only with a verified
contributor email. Addresses under `models.invalid` are explicit local model labels,
not contact addresses or verified GitHub accounts. See the
[GitHub co-author documentation](https://docs.github.com/en/pull-requests/how-tos/commit-changes/creating-a-commit-with-multiple-authors).
