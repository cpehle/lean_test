# LeanTest

A Rust-inspired test framework for Lean4.

## Features

- `@[test]` attribute to mark test functions
- `@[test_ignore]` for tests to skip by default
- `@[test_should_error]` for tests expected to fail
- Assertion helpers: `assertTrue`, `assertEqual`, `assertThrows`, etc.
- Test runner with filtering, fail-fast, and optional parallel execution
- Integration with `lake test`

## Installation

Add to your `lakefile.lean`:

```lean
require LeanTest from git "https://github.com/..." @ "main"
```

## Usage

### Writing Tests

```lean
import LeanTest

@[test]
def testAddition : IO Unit := do
  LeanTest.assertEqual (2 + 2) 4

@[test]
def testComparison : IO Unit := do
  LeanTest.assertTrue (1 < 2)
  LeanTest.assertFalse (2 < 1)

@[test_ignore]
def testSlowOperation : IO Unit := do
  -- Skipped by default, run with --ignored
  IO.sleep 10000

@[test_should_error]
def testExpectedError : IO Unit := do
  throw <| IO.userError "expected"
```

### Creating a Test Driver

Create a `TestDriver.lean` and example is provided in the repo root.

Add to your `lakefile.lean`:

```lean
@[test_driver]
lean_exe test where
  root := `TestDriver
```

### Running Tests

```bash
lake test                     # Run all tests
lake test -- --filter foo     # Run tests matching "foo"
lake test -- --ignored        # Include ignored tests
lake test -- --fail-fast      # Stop on first failure
lake test -- -j 4             # Short form for concurrent execution
lake test -- --jobs 4         # Run up to 4 tests concurrently
lake test -- --help           # Show help
```

Parallel execution is opt-in. Tests run sequentially by default, and tests enabled via
`--jobs` should avoid unsynchronized shared mutable state. LeanTest does not yet provide a
per-test `serial` marker, so suites with serialization constraints should run with `--jobs 1`
or move those tests into a separate test driver.

## Assertions

| Function | Description |
|----------|-------------|
| `assertTrue cond` | Assert condition is true |
| `assertFalse cond` | Assert condition is false |
| `assertEqual a b` | Assert two values are equal |
| `assertNotEqual a b` | Assert two values are not equal |
| `assertSome opt` | Assert option is Some |
| `assertNone opt` | Assert option is None |
| `assertThrows action` | Assert action throws an error |
| `assertNoThrow action` | Assert action doesn't throw |
| `assertSatisfies v p msg` | Assert value satisfies predicate |
| `fail msg` | Unconditionally fail |

## Project Structure

```
LeanTest/
├── lakefile.lean
├── lean-toolchain
├── LeanTest.lean           # Main module (re-exports everything)
├── LeanTest/
│   ├── Basic.lean          # Core types
│   ├── Assert.lean         # Assertion helpers
│   ├── Attr.lean           # @[test] attributes
│   └── Runner.lean         # Test runner
├── Test/
│   └── Basic.lean          # Example tests
└── TestDriver.lean         # Test driver executable
```

## License

Apache 2.0
