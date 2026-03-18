/-
Copyright (c) 2026 Christian Pehle. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Test Runner for LeanTest
-/

import Lean
import LeanTest.Basic
import LeanTest.Assert
import LeanTest.Attr

namespace LeanTest

open Lean

/-- Configuration for running tests. -/
structure RunConfig where
  /-- Include tests marked as ignored. -/
  includeIgnored : Bool := false
  /-- Stop on first failure. -/
  failFast : Bool := false
  /-- Filter tests by name pattern (substring match). -/
  filter : Option String := none
  /-- Maximum number of tests to run concurrently. -/
  jobs : Nat := 1
  deriving Inhabited, Repr

/-- Default run configuration. -/
def RunConfig.default : RunConfig := {}

/-- Get the display name for a test. -/
def getTestName (entry : TestEntry) : String :=
  entry.config.name.getD entry.declName.toString

/-- Sort tests into a deterministic execution order. -/
def sortTests (tests : Array TestEntry) : Array TestEntry :=
  tests.qsort fun a b =>
    let aName := getTestName a
    let bName := getTestName b
    if aName == bName then
      compare a.declName.toString b.declName.toString |>.isLT
    else
      compare aName bName |>.isLT

/-- Filter tests based on run configuration and normalize ignored tests. -/
def prepareTests (config : RunConfig) (tests : Array TestEntry) : Array TestEntry :=
  sortTests <| tests.filterMap fun entry =>
    let ignoreOk := !entry.config.ignore || config.includeIgnored
    let filterOk := match config.filter with
      | none => true
      | some pattern => entry.declName.toString.containsSubstr pattern
    if ignoreOk && filterOk then
      let entry :=
        if config.includeIgnored && entry.config.ignore then
          { entry with config := { entry.config with ignore := false } }
        else
          entry
      some entry
    else
      none

/-- True if the configuration enables parallel test execution. -/
def RunConfig.parallelEnabled (config : RunConfig) : Bool :=
  config.jobs > 1

/-- Run a single test and return the result. -/
unsafe def runSingleTest (env : Environment) (opts : Options) (entry : TestEntry) : IO TestResult := do
  let startTime ← IO.monoMsNow

  if entry.config.ignore then
    return .skipped "ignored"

  try
    let testFn ← IO.ofExcept <| env.evalConst (IO Unit) opts entry.declName
    testFn

    let endTime ← IO.monoMsNow
    let duration := endTime - startTime

    if entry.config.shouldError then
      return .failed duration "expected error but test passed"
    else
      return .passed duration

  catch e =>
    let endTime ← IO.monoMsNow
    let duration := endTime - startTime
    let errMsg := toString e

    if entry.config.shouldError then
      match entry.config.errorPattern with
      | none => return .passed duration
      | some pattern =>
        if errMsg.containsSubstr pattern then
          return .passed duration
        else
          return .failed duration s!"error did not match pattern '{pattern}': {errMsg}"
    else
      return .failed duration errMsg

/-- Format a single test result for display. -/
def formatResult (name : String) (result : TestResult) : String :=
  let status := match result with
    | .passed duration => s!"ok ({duration}ms)"
    | .failed duration msg => s!"FAILED ({duration}ms)\n  Error: {msg}"
    | .skipped reason => s!"skipped ({reason})"
  let maxNameLen := 50
  let nameLen := min maxNameLen name.length
  let dots := String.ofList (List.replicate (maxNameLen - nameLen) '.')
  s!"{name} {dots} {status}"

/-- Format the test summary for display. -/
def formatSummary (summary : TestSummary) : String :=
  s!"\nTest Summary:
  Passed:   {summary.passed}
  Failed:   {summary.failed}
  Skipped:  {summary.skipped}
  Total:    {summary.total}
  Duration: {summary.duration}ms"

/-- Update aggregate counters with a single test result. -/
def updateCounts (summary : TestSummary) (declName : Name) (result : TestResult) : TestSummary :=
  let summary := { summary with results := summary.results.push (declName, result) }
  match result with
  | .passed _ => { summary with passed := summary.passed + 1 }
  | .failed _ _ => { summary with failed := summary.failed + 1 }
  | .skipped _ => { summary with skipped := summary.skipped + 1 }

/-- Create an empty summary for the given number of tests. -/
def mkEmptySummary (total : Nat) : TestSummary :=
  {
    total := total
    passed := 0
    failed := 0
    skipped := 0
    duration := 0
    results := #[]
  }

/-- Result payload returned by a worker task. -/
private structure CompletedTest where
  index : Nat
  declName : Name
  name : String
  result : TestResult

/-- Run tests sequentially. -/
unsafe def runTestsSequential (env : Environment) (opts : Options) (tests : Array TestEntry) (config : RunConfig) :
    IO TestSummary := do
  let mut summary := mkEmptySummary tests.size
  let mut stop := false
  let mut index := 0
  while h : index < tests.size do
    let entry := tests[index]
    let name := getTestName entry
    let result ←
      if stop then
        pure <| .skipped "fail-fast"
      else
        runSingleTest env opts entry
    IO.println (formatResult name result)
    summary := updateCounts summary entry.declName result
    if config.failFast then
      match result with
      | .failed _ _ => stop := true
      | _ => pure ()
    index := index + 1
  return summary

/-- Start a single test on the Lean task pool. -/
unsafe def spawnTestTask (env : Environment) (opts : Options) (index : Nat) (entry : TestEntry) :
    IO (Task (Except IO.Error CompletedTest)) := do
  IO.asTask do
    let result ← runSingleTest env opts entry
    return {
      index := index
      declName := entry.declName
      name := getTestName entry
      result := result
    }

/-- Flush contiguous completed test results in discovery order. -/
private def flushCompleted
    (buffer : Array (Option CompletedTest))
    (nextIndex : Nat)
    (summary : TestSummary) :
    IO (Nat × TestSummary) := do
  let mut nextIndex := nextIndex
  let mut summary := summary
  while h : nextIndex < buffer.size do
    match buffer[nextIndex] with
    | some completed =>
      IO.println (formatResult completed.name completed.result)
      summary := updateCounts summary completed.declName completed.result
      nextIndex := nextIndex + 1
    | none => break
  return (nextIndex, summary)

/-- Run tests with bounded parallelism while keeping output deterministic. -/
unsafe def runTestsParallel (env : Environment) (opts : Options) (tests : Array TestEntry) (config : RunConfig) :
    IO TestSummary := do
  let total := tests.size
  let workerCount := min total config.jobs
  let mut summary := mkEmptySummary total
  let mut completed : Array (Option CompletedTest) := Array.replicate total none
  let mut nextToStart := 0
  let mut nextToPrint := 0
  let mut stopScheduling := false
  let mut active : List (Task (Except IO.Error CompletedTest)) := []

  while h : nextToStart < workerCount do
    let task ← spawnTestTask env opts nextToStart tests[nextToStart]!
    active := task :: active
    nextToStart := nextToStart + 1

  while h : !active.isEmpty do
    let (taskResult, remaining) ←
      match active with
      | [] => unreachable!
      | head :: tail => IO.waitAny' (head :: tail)
    active := remaining

    let completedTest ← match taskResult with
      | .ok done => pure done
      | .error err =>
        pure {
          index := nextToPrint
          declName := tests[nextToPrint]!.declName
          name := getTestName tests[nextToPrint]!
          result := .failed 0 s!"unexpected task failure: {err}"
        }

    completed := completed.set! completedTest.index (some completedTest)
    let flushed ← flushCompleted completed nextToPrint summary
    nextToPrint := flushed.1
    summary := flushed.2

    if config.failFast then
      match completedTest.result with
      | .failed _ _ => stopScheduling := true
      | _ => pure ()

    if !stopScheduling && nextToStart < total then
      let task ← spawnTestTask env opts nextToStart tests[nextToStart]!
      active := task :: active
      nextToStart := nextToStart + 1

  while h : nextToStart < total do
    let entry := tests[nextToStart]!
    let result : TestResult := .skipped "fail-fast"
    IO.println (formatResult (getTestName entry) result)
    summary := updateCounts summary entry.declName result
    nextToStart := nextToStart + 1

  return summary

/-- Run all tests and return a summary. -/
unsafe def runTests (env : Environment) (opts : Options) (config : RunConfig := {}) : IO TestSummary := do
  let allTests := getTests env
  let tests := prepareTests config allTests

  IO.println s!"Running {tests.size} tests...\n"

  let startTime ← IO.monoMsNow
  let summary ←
    if config.parallelEnabled then
      runTestsParallel env opts tests config
    else
      runTestsSequential env opts tests config

  let endTime ← IO.monoMsNow
  let duration := endTime - startTime

  let summary := { summary with duration := duration }

  IO.println (formatSummary summary)

  return summary

/-- Run tests and exit with appropriate exit code.

Returns 0 if all tests passed, 1 otherwise.
-/
unsafe def runTestsAndExit (env : Environment) (opts : Options) (config : RunConfig := {}) : IO UInt32 := do
  let summary ← runTests env opts config
  return if summary.allPassed then 0 else 1

end LeanTest
