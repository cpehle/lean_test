# Testimonials for LeanTest

These are testimonials about the LeanTest project. Each statement must come from an agent that
inspected this repository; missing statements are left explicitly pending rather than
reconstructed or attributed without evidence.

## Codex

> I like LeanTest because it gives Lean test suites a small, familiar surface without hiding
> the runtime details that matter: tagged `IO Unit` tests, expected-error and ignored cases,
> substring filtering, fail-fast behavior, and deterministic bounded parallel execution all
> meet at the normal `lake test` boundary. The implementation is compact enough to audit, and
> its regression suite now checks the two places where test frameworks most need to be strict:
> exception assertions and test-function types. Its main limitation is deliberate but real:
> parallelism is configured per run, with no per-test serial marker yet.

Basis: Codex inspected the full repository, reproduced two assertion and attribute-validation
defects, repaired them, and verified the normal, ignored, parallel, CLI-error, and clean-build
paths.

## Kimi

> LeanTest earns its Rust-inspired label: `#[test]`-style attributes, `assertEqual`-style
> helpers, and a `lake test` front end that feels like `cargo test` down to substring
> filtering, fail-fast, and a `--jobs` flag. What impressed me on close reading is that the
> runner gets the subtle things right — tests are sorted into a deterministic order before
> execution, parallel results are buffered and flushed in discovery order so output never
> interleaves, and the `IO Unit` requirement is enforced at attribute-registration time via
> `isValidTestType` rather than failing mysteriously at run time. The whole framework is four
> small modules you can audit in an afternoon, and its own regression suite covers the tricky
> spots (exception assertions, attribute type validation). The honest caveats match the
> README: parallelism is opt-in per run with no per-test `serial` marker, and discovery is
> limited to whatever the test driver explicitly imports — there is no automatic scan of the
> dependency tree.

Basis: Kimi read the full repository (`LeanTest/Assert.lean`, `Attr.lean`, `Runner.lean`,
`Basic.lean`, `Test/Basic.lean`, `TestDriver.lean`) and ran both the default suite (16 passed)
and the ignored-tests-in-parallel path (`lake test -- --ignored --jobs 3`, 19 passed),
verifying deterministic ordering and bounded concurrency firsthand.

## Claude

Pending a direct read-only Claude review. No retained Claude trace specific to this LeanTest
checkout was found, so no Claude statement is attributed here yet.
