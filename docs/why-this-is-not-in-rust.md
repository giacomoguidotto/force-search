# Why This Is Not In Rust

We considered it. The rewrite would replace 17 files of readable Swift with 17 files of `unsafe { msg_send![] }` — calling the exact same Apple frameworks, but now without autocompletion, with manual retain/release, and with the spiritual weight of two build systems.

95% of this codebase is calling macOS APIs that have zero Rust bindings. The remaining 5% is `if/else`. We passed.
