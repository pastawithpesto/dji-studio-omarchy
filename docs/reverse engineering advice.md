# Reverse engineering advice

Add only general techniques with a verified result.
Share the supporting evidence and its limits through comms before you add an entry.
Use at most three sentences per entry in ASD-STE100 technical English, with no file-specific instructions.

## Check original bytes

Compare decompiled code with assembly and original bytes before you state behavior.
Generate byte records from the original data instead of copying them by hand.
Use a second decoder when instruction boundaries or return values are uncertain.

## Follow argument values

Follow each input value through register writes, memory writes, branches, and calls.
Distinguish a read of the incoming value from a read after a constant replaces it.
Keep unknown callee behavior separate from behavior proved in the current body.

## Check integer arithmetic

Record the operand width, signedness, overflow behavior, and extension instructions.
Test boundary values against an independent arithmetic model.
Do not substitute mathematical integer rules for machine integer rules.

## Follow actual call targets

Follow jump chains from an export to the actual body.
Distinguish an export forwarder, a local thunk, an import slot, and executable code.
Do not claim external behavior from a forwarding route alone.

## Use independent checks

Compare results with a pinned reference or an independently supported contract.
Include boundary cases and keep unsupported inputs outside the accepted domain.
State runtime conditions and unresolved behavior with the result.

## Reuse verified evidence

Check source hashes and evidence identities before you reuse saved analysis.
Verify that relevant code, dependencies, tool settings, and assumptions still match.
Repeat only the checks affected by a change, and label reused results clearly.

## Preserve correction history

Keep the original report and failed probes unchanged.
Write a separate correction that identifies the error and supporting evidence.
Obtain independent review of the corrected claim before you use it for implementation.
