# Isolated finite-number fixtures

Original build: DJI Studio 1.0.0.30839 `nle_core.dll`, SHA256
`3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1`.
Function: `0x18014e370..0x18014f970`, end-exclusive. Exact source/table/REA and
contract pins are in `provenance.json`. Static finite source composition was
independently approved in bus727; R1 independent interface policies in bus703.
Code approval and root integration are separate gates.

* `literal-fixtures.json`: byte-preserved 52 mathematical/source examples from
  frozen R1, independently validated as exact rational rounding intervals.
* `native-policy-fixtures.json`: byte-preserved 42 R1 independent policy cases;
  these specify error order, unchanged errors and successful prefix ownership.
* `rational-fixtures.json`: 27,387 positive finite magnitude expectations from
  an independent exact rational interval/candidate oracle. Native tests apply
  both signs and three canary patterns. All2046 normal exponent fields have ten
  fraction boundaries; additional exact-integral admission boundaries, explicit
  source guard/midpoint witnesses, subnormal power boundaries and seeded normal/
  subnormal samples are included. No author formatter or peer script generated
  expected outputs. Notation/integral suffix follows the separately approved
  source contract. Bounded mathematical checks imply no universal shortest theorem.

Reproduction script and logs are owned analysis artifacts under
`sol-calibration-review/swarm-20261010-2154/number-format-code/` in the evidence
workspace (`generate_fixtures.py`, `verify_provenance.py`, `run_checks.py`).
They are not application dependencies. Writer tests additionally cover every
four-digit residue, integral/subnormal leading lengths, all eight trim families,
and the exponent suffix domain using independent decimal spelling in tests.

The formatter uses one initialized checked64-byte native scratch.64 is an
independent cap, not vendor allocation/ABI evidence; <=25 is the separately
reviewed logical initialized-prefix bound. Production performs no heap
allocation, unsafe/FFI, floating operations, process calls or library formatting
of input values. Error Display writes into the caller's formatting sink.
Caller allocation by that sink is outside the internal no-allocation policy.
The formatter is isolated from DOM/CLI/GUI/audio. No vendor execution, Windows
recording, project compatibility or runtime/full-feature parity is claimed.
