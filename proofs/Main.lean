-- def OnePlusOneIsTwo : Prop := 1 + 1 = 2

theorem onePlusOneIsTwo : 1 + 1 = 2 := by
  simp

-- theorem addAndAppend : 1 + 1 = 2 ∧ "Str".append "ing" = "String" := by
  -- simp

-- theorem addAndAppend : 1 + 1 = 2 ∧ "Str".append "ing" = "String" := by simp

theorem andImpliesOr : A ∨ B -> A ∨ B :=
  fun andEvidence =>
    match andEvidence with
    | And.intro a b => Or.inl a

-- def OnePlusOneIsFifteen : Prop := 1 + 1 = 15

-- theorem onePlusOneIsFifteen : OnePlusOneIsFifteen := rfl
