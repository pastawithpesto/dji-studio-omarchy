# Local unscoped member-enum option

This is a local derivative of the pinned crates.io `cxx-qt-gen0.10.0` package.
[UPSTREAM.json](UPSTREAM.json) pins the archive and every copied upstream source
file. SPDX notices and the original MIT/Apache2.0 license choices are preserved.
The license texts come from the official upstream v0.10.0 tag.

The unscoped option changes three generator implementation files:

- `src/parser/qenum.rs` accepts the marker `#[qenum_unscoped]` on QObject member
  enums. It rejects marker arguments and standalone unscoped enums. It stores
  one boolean option. The default is false.
- `src/generator/cpp/qenum.rs` emits an unscoped enum for that explicit option.
  The default enum class output stays unchanged. Names, values, signed32 storage,
  aliases and all other generation paths stay unchanged.
- `src/generator/rust/qenum.rs` uses the qualified CXX alias ID only for the
  explicit unscoped option. This fixes the released namespaced member-alias ID
  mismatch needed by two distinct original `EnumType` declarations. Default
  output, including its legacy ID behavior, stays unchanged.

This is a generic Rust binding-generator option. It contains no DJI-specific
value or type name. It does not edit emitted C++ or implement behavior in C++.
CXX-Qt0.10.0 already imports member enums as custom trivial types. It does not
use scoped-enum forward declarations for those members. Standalone enums retain
the default generator path because CXX supplies their enum declarations.

The added integration test compares all three unchanged upstream qenum snapshots
and separately pinned raw output from an independently compiled stock generator.
Those frozen snapshots keep their original bytes with a `.txt` suffix. They are
reference evidence, not compiled C++ application files. The test also checks that
the explicit option changes only the C++ enum scope and rejects unsupported forms.
No upstream source test is removed or rewritten. Full upstream tests need their
omitted original fixture set; only the declared integration test is runnable in
this trimmed dependency copy.

The application runtime check must verify `QMetaEnum::isScoped()==false` on both
live original-name QObject types. A source-generator check alone does not prove
native metadata or QML construction compatibility. Independent compiler-change
review remains a separate gate.

The root integration copy can also carry separate signal qualification and shared
callback repairs, documented there in `SIGNAL-QUALIFICATION.md` and
`SHARED-SIGNAL.md`. Those have separate source reviews and native checks. They are
not part of this standalone candidate's three unscoped-option implementation
changes, and this module does not overwrite their root-owned code.
