# Original resource review and integration

Owner: @pastawithpesto

Claim: `gui/original/**` and this task file.

The complete resource bundle already exists. Reuse source commit
`632efe2a3e63296f30a980606d424284d8876a3c`, authored by Luna B2.
This PR carries that exact change onto the documented baseline.
Do not repeat resource extraction or claim another implementation of this bundle.

Next work:

1. Verify the source pins and all 1,826 resource aliases.
2. Confirm that all 577 baseline payloads remain unchanged.
3. Independently check the CMake attachment and RCC payload results.
4. Obtain independent Sol High code review and Astra High milestone verification.
5. Integrate only after the required checks pass.

The original QML has 410 aliases. Resource recovery does not prove runtime UI
parity. Native controllers and Windows comparison remain separate work.
This PR reserves review and integration. It does not approve the bundle.
