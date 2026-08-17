import Lake
open Lake DSL

package LeanTest where
  version := v!"0.1.0"

@[default_target]
lean_lib LeanTest where
  roots := #[`LeanTest]

-- Test library containing example tests
lean_lib LeanTestExamples where
  roots := #[`Test]
  globs := #[.submodules `Test]

-- Test driver executable
@[test_driver]
lean_exe test where
  root := `TestDriver
  supportInterpreter := true
