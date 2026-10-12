# Clear GitHub communication

These instructions apply to agents that write GitHub titles, PR descriptions,
comments, review results, and progress updates for this repository.

## Write for people first

- Use plain words that a human reviewer can understand.
- State the result first.
- Explain what changed and why it matters.
- State whether the checks passed.
- State what still needs fixing.
- Name the person or role that must act next.
- Put important problems in the main explanation.
- Explain a technical term when the reader needs it.
- Do not make the reader decode agent names, status codes, or long hashes.

## Use clear technical English

Use ASD-STE100 Simplified Technical English when technical wording is needed.
Keep sentences short.
Use the same term for the same item.
Put one action in each instruction.
Use active voice.
Write complete sentences.
Keep GitHub summaries clear for human reviewers.

Preserve exact code, filenames, source strings, hashes, and addresses.
Do not rewrite historical evidence or reviewed records to change their style.

## Put extra agent details in a separate note

Use the heading **Note for LLMs** for details that other agents need.
The human explanation must be complete without this note.
Keep a blocking problem and its required action in the human explanation.
Use the note for exact commits, file hashes, worktree paths, and evidence records.
Use clear technical English in this note too.
Do not include private reasoning or credentials.

## Example GitHub update

The Linux build and tests passed. The sample video exported correctly.
The PR is waiting for the repository owner's approval.
The owner must review this version before it can merge.

<details>
<summary>Note for LLMs</summary>

Record the exact reviewed commit here.
Link the independent review, test run, and verification report.
State the current main commit and any limits of the evidence.

</details>

## Check before posting

Read the human explanation by itself.
Confirm that it states the result, the remaining problem, and the next action.
Confirm that the technical note supports the same result.
