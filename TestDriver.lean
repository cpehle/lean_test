/-
Copyright (c) 2026 Christian Pehle. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Test Driver

This is the main entry point for `lake test`. It discovers and runs all
tests marked with @[test] in the imported modules.
-/

import LeanTest
import Lean.Util.Path
import Test.Basic

/-- Parse a positive integer for `--jobs`. -/
def parseJobs (value : String) : IO Nat := do
  match value.toNat? with
  | some (Nat.succ n) => pure (Nat.succ n)
  | some 0 => throw <| IO.userError "--jobs must be greater than 0"
  | none => throw <| IO.userError s!"invalid value for --jobs: {value}"

/-- Parse command line arguments into a RunConfig. -/
def parseArgs (args : List String) : IO LeanTest.RunConfig := do
  let mut config : LeanTest.RunConfig := {}
  let mut remaining := args
  while _h : !remaining.isEmpty do
    match remaining with
    | "--filter" :: [] =>
      throw <| IO.userError "--filter requires a pattern"
    | "--filter" :: pattern :: rest =>
      config := { config with filter := some pattern }
      remaining := rest
    | "--ignored" :: rest =>
      config := { config with includeIgnored := true }
      remaining := rest
    | "--fail-fast" :: rest =>
      config := { config with failFast := true }
      remaining := rest
    | "--jobs" :: [] =>
      throw <| IO.userError "--jobs requires a positive integer"
    | "--jobs" :: value :: rest =>
      config := { config with jobs := ← parseJobs value }
      remaining := rest
    | "-j" :: [] =>
      throw <| IO.userError "-j requires a positive integer"
    | "-j" :: value :: rest =>
      config := { config with jobs := ← parseJobs value }
      remaining := rest
    | "--help" :: _ =>
      IO.println "Usage: lake test [OPTIONS]"
      IO.println ""
      IO.println "Options:"
      IO.println "  --filter PATTERN  Only run tests matching PATTERN"
      IO.println "  --ignored         Include tests marked as ignored"
      IO.println "  --fail-fast       Stop on first failure"
      IO.println "  --jobs, -j N      Run up to N tests concurrently"
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
