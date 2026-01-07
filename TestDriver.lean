/-
Copyright (c) 2026 Christian Pehle. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Test Driver

This is the main entry point for `lake test`. It discovers and runs all
tests marked with @[test] in the imported modules.
-/

import LeanTest
import Lean.Util.Path

/-- Parse command line arguments into a RunConfig. -/
def parseArgs (args : List String) : IO LeanTest.RunConfig := do
  let mut config : LeanTest.RunConfig := {}
  let mut remaining := args
  while _h : !remaining.isEmpty do
    match remaining with
    | "--filter" :: pattern :: rest =>
      config := { config with filter := some pattern }
      remaining := rest
    | "--ignored" :: rest =>
      config := { config with includeIgnored := true }
      remaining := rest
    | "--fail-fast" :: rest =>
      config := { config with failFast := true }
      remaining := rest
    | "--help" :: _ =>
      IO.println "Usage: lake test [OPTIONS]"
      IO.println ""
      IO.println "Options:"
      IO.println "  --filter PATTERN  Only run tests matching PATTERN"
      IO.println "  --ignored         Include tests marked as ignored"
      IO.println "  --fail-fast       Stop on first failure"
      IO.println "  --help            Show this help"
      IO.Process.exit 0
    | _ :: rest =>
      remaining := rest
    | [] => remaining := []
  return config

/-- Main entry point for the test driver. -/
unsafe def main (args : List String) : IO UInt32 := do
  let config ← parseArgs args

  -- Initialize search path for imports
  Lean.initSearchPath (← Lean.findSysroot)

  -- Enable execution of module initializers
  Lean.enableInitializersExecution

  -- Import the test module to get the environment with registered tests
  -- We need to import LeanTest first so the extension is registered
  let env ← Lean.importModules
    #[{ module := `LeanTest }, { module := `Test.Basic }]
    {}

  LeanTest.runTestsAndExit env {} config
