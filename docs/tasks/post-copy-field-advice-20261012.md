# Field writes after an object copy

Owner: root.

Add one general entry to `docs/reverse engineering advice.md`. Use exactly three sentences. The entry must tell the reader to trace field stores between an object copy and the consumer call. Do not add file-specific instructions to the advice.

Scope: this task file and the advice file only. Use a separate source branch on fresh main. Read current PR claims and the watchdog before the advice edit.

Supporting result: Luna High saved a caller record-copy contract. Independent Sol High found ten intervening field writes. A separate correction passed original-byte checks and independent review. The preserved local record is `reconstruction/root-luna-high-research-20261012/stitching/correction-01`. Sol review bus 3850 records the bounded acceptance. The technique is general; runtime field meaning and image parity remain outside it.

Validation: check the exact two-path diff, unchanged prior advice entries, sentence count, technical English and source links. No application behavior changes. No application tests are needed. Obtain independent source review and separate Sol High milestone verification before merge.
