# Fuzzers

Mac Drag Scroll keeps fuzz harnesses separate from the app target so release builds stay small and deterministic.

`PreferenceInputFuzzer.swift` exercises property-list parsing plus normalization paths used for preference-like text such as bundle identifiers, URLs, and boolean settings. The harness exposes `LLVMFuzzerTestOneInput` behind the `FUZZING` compilation condition for Swift toolchains that support libFuzzer.

CI compiles the harnesses with `-D FUZZING` as a syntax and linkage smoke test. Full fuzzing can be run with a Swift toolchain and target platform that supports libFuzzer sanitizers.
