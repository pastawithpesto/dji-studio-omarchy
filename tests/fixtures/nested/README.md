# Synthetic nested transport acceptance

The first18 carriers are exact copies of the independent Luna-A3 oracle frozen
under `sol-review/swarm-20261010-2154/independent-reproduction/nested-v2`.
The approved contract is `NESTED-TRANSPORT-CONTRACT-R1.md`, SHA256
`f181baeefc320bb3ad4031d199ea1247c990e5f16ce6347e91187382f5701a95`.
`acceptance.json` pins each container, the source oracle/generator, complete
carrier bytes, inventories, raw stream timing and packet transport expectations.

Four additional `first-*` carriers have two distinct recognized boxes in
opposite orders, or an empty recognized first box. Their expected first-match
selection follows the original static scan loop and approved native policy;
they are separate from the frozen18. The WAB-first carrier retains an OQB outer
encoder: it proves selection and byte transport, with no assertion of WAB
semantic compatibility under that encoder.

Reimport deterministically from the frozen artifact directory into a new owned
directory with:

```sh
python3 import_oracle.py FROZEN_ORACLE_DIRECTORY NEW_OUTPUT_DIRECTORY
```

The tests use actual local FFprobe base64 transport and the public library/CLI.
Process/error/cleanup edge tests use explicitly synthetic trusted probe scripts.
These fixtures establish no original-camera, Windows-loader, UI or processing
parity. No timestamp units, axes or outer/inner byte-coordinate mapping is inferred.
