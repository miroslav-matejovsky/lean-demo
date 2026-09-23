# 03 · Specification vs. implementation

This lesson is the hinge between "Lean for maths" and "Lean for architecture".

| | Specification | Implementation |
|---|---|---|
| Optimised for | clarity, obviousness | speed, memory, platform |
| Written by | architect / domain expert | engineering team |
| Question it answers | *what* is correct | *how* to compute it |

A **refinement proof** shows that the implementation computes exactly what the
spec says, for all inputs. `sumImpl_correct` below is a tiny but complete example.

```lean
--8<-- "lean/Tutorial/SpecVsImpl.lean"
```

## Three ways a spec can relate to code

1. **Reference function + refinement proof** (`sumSpec` / `sumImpl`)
   The strongest form. It only works when the implementation is *also in Lean*
   (or translated into Lean).
2. **Properties** (`maxOf_ge`, `maxOf_mem`)
   The spec says what must hold, not how. It is good for policies, and the Order
   invariant in Part 2 takes this form.
3. **Executable oracle** (`#eval sumSpec …`)
   The spec *runs*, so it can produce expected outputs for code in other
   languages. This is **weaker than a proof** (it covers only the inputs you
   sample), but it works for .NET and Go **today**, with no change to how teams write code.

Part 2 combines (2) and (3). Properties are proven **about the spec**, and the
oracle checks that implementations **behave like the spec**. The gap between
those two guarantees is examined honestly in [Limits](../discussion/limits.md).
