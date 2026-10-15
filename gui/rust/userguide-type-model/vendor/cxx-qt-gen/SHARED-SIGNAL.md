# Shared signal callback option

The explicit `#[qsignal_shared]` marker selects a shared Rust `Fn` callback.
The default `FnMut` callback and storage stay unchanged. The marker takes no
arguments. It does not change the Qt signal, object type, or public metaobject.

The shared callback requires `Send + Sync`. Its Rust trampoline receives an
immutable handler reference and calls the boxed function through an immutable
reference. A nested signal call does not create a second mutable reference to
the same callback. The application must still respect QObject thread affinity
and object lifetime. This option does not make a raw QObject pointer safe.

The generated shared storage follows CXX-Qt0.10.0's signalhandler.rs: a
repr-transparent boxed callback with the same CXX type ID and move/drop path.
It uses an immutable field directly, so it needs no access to a private runtime
field or guessed native layout. Existing native and Rust assertions check its
two-word size and alignment. Native callback and destruction tests remain
required before acceptance.

The source change adds a parser flag and changes only the marked signal's Rust
binding output. C++ signal-helper output stays unchanged. The test checks both
the immutable CXX trampoline and Rust body, callback bounds, storage, type ID
implementation, unchanged default dispatch, and rejected marker arguments.
The namespace test also uses the supported C++Qt block for const receivers.

No application C++ or emitted-code rewrite is added. These are local Rust
binding-generator changes. UPSTREAM.json keeps the original archive and file
pins. SHARED-SIGNAL-UPSTREAM.json pins the runtime storage source used here.
