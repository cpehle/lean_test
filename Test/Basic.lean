/-
Copyright (c) 2026 Christian Pehle. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Example Tests

This module demonstrates how to write tests using LeanTest.
-/

import LeanTest

namespace Test.Basic

/-! ## Basic Arithmetic Tests -/

@[test]
def testAddition : IO Unit := do
  LeanTest.assertEqual (2 + 2) 4
  LeanTest.assertEqual (0 + 0) 0
  LeanTest.assertEqual (100 + 200) 300

@[test]
def testMultiplication : IO Unit := do
  LeanTest.assertEqual (3 * 4) 12
  LeanTest.assertEqual (0 * 100) 0
  LeanTest.assertEqual (7 * 1) 7

@[test]
def testSubtraction : IO Unit := do
  LeanTest.assertEqual (10 - 3) 7
  LeanTest.assertEqual (5 - 5) 0

/-! ## Boolean Tests -/

@[test]
def testBooleanAssertions : IO Unit := do
  LeanTest.assertTrue (1 < 2)
  LeanTest.assertTrue (10 > 5)
  LeanTest.assertFalse (1 > 2)
  LeanTest.assertFalse (5 == 10)

@[test]
def testComparisons : IO Unit := do
  LeanTest.assertTrue (1 ≤ 1)
  LeanTest.assertTrue (1 ≤ 2)
  LeanTest.assertFalse (2 ≤ 1)

/-! ## Option Tests -/

@[test]
def testOptionSome : IO Unit := do
  let result : Option Nat := some 42
  LeanTest.assertSome result
  LeanTest.assertEqual result (some 42)

@[test]
def testOptionNone : IO Unit := do
  let result : Option Nat := none
  LeanTest.assertNone result

/-! ## String Tests -/

@[test]
def testStringEquality : IO Unit := do
  LeanTest.assertEqual "hello" "hello"
  LeanTest.assertNotEqual "hello" "world"

@[test]
def testStringOperations : IO Unit := do
  LeanTest.assertEqual ("hello" ++ " " ++ "world") "hello world"
  LeanTest.assertEqual "hello".length 5

/-! ## List Tests -/

@[test]
def testListOperations : IO Unit := do
  LeanTest.assertEqual ([1, 2, 3].length) 3
  LeanTest.assertEqual ([1, 2] ++ [3, 4]) [1, 2, 3, 4]
  LeanTest.assertEqual ([1, 2, 3].reverse) [3, 2, 1]

/-! ## Ignored Test -/

@[test_ignore]
def testSlowOperation : IO Unit := do
  -- This test is skipped by default
  -- Run with `lake test -- --ignored` to include it
  IO.sleep 250
  LeanTest.assertTrue true

@[test_ignore]
def testSlowOperationTwo : IO Unit := do
  IO.sleep 250
  LeanTest.assertTrue true

@[test_ignore]
def testSlowOperationThree : IO Unit := do
  IO.sleep 250
  LeanTest.assertTrue true

/-! ## Expected Error Test -/

@[test_should_error]
def testExpectedError : IO Unit := do
  throw <| IO.userError "this error is expected"

@[test_should_error]
def testDivisionByZero : IO Unit := do
  let x : Nat := 1
  let y : Nat := 0
  if y == 0 then
    throw <| IO.userError "division by zero"
  let _ := x / y
  pure ()

/-! ## Assertion Helper Regression Tests -/

@[test]
def testAssertThrowsAcceptsThrownError : IO Unit := do
  LeanTest.assertThrows
    (throw <| IO.userError "expected sentinel" : IO Unit)
    (some "expected sentinel")

@[test]
def testAssertThrowsRejectsSuccessfulAction : IO Unit := do
  let rejected ←
    try
      LeanTest.assertThrows (pure ())
      pure false
    catch _ =>
      pure true
  LeanTest.assertTrue rejected

@[test]
def testAssertThrowsRejectsPatternMismatch : IO Unit := do
  let rejected ←
    try
      LeanTest.assertThrows
        (throw <| IO.userError "actual sentinel" : IO Unit)
        (some "different sentinel")
      pure false
    catch _ =>
      pure true
  LeanTest.assertTrue rejected

/-! ## Attribute Validation Regression Tests -/

@[test]
def testAttributeRequiresIOUnit : IO Unit := do
  let ioUnit := Lean.mkApp (Lean.mkConst ``IO [.zero]) (Lean.mkConst ``Unit)
  let ioNat := Lean.mkApp (Lean.mkConst ``IO [.zero]) (Lean.mkConst ``Nat)
  LeanTest.assertTrue (LeanTest.isValidTestType ioUnit)
  LeanTest.assertFalse (LeanTest.isValidTestType ioNat)
  LeanTest.assertFalse (LeanTest.isValidTestType (Lean.mkConst ``Nat))

end Test.Basic
