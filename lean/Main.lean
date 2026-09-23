import Truth

open Truth.Export

/-- Every artifact derived from the specs, relative to the repository root. -/
def artifacts : List (String × String) := [
  ("contracts/zone/manifest.json", Zone.manifest.pretty ++ "\n"),
  ("contracts/zone/vectors.json", Zone.vectors.pretty (width := 220) ++ "\n"),
  ("contracts/health/manifest.json", Health.manifest.pretty ++ "\n"),
  ("contracts/health/vectors.json", Health.vectors.pretty (width := 220) ++ "\n"),
  ("impl/dotnet/src/Surveillance/Zone/Generated/Contract.g.cs", Zone.csharp),
  ("impl/dotnet/src/Surveillance/Health/Generated/Contract.g.cs", Health.csharp),
  ("impl/go/zone/contract_gen.go", Zone.golang),
  ("impl/go/health/contract_gen.go", Health.golang),
  ("docs/reference/zone-alarm.md", Zone.doc),
  ("docs/reference/health-view.md", Health.doc)
]

def exportAll (root : System.FilePath) : IO Unit := do
  for (rel, content) in artifacts do
    let path := root / rel
    if let some dir := path.parent then IO.FS.createDirAll dir
    IO.FS.writeFile path content
    IO.println s!"wrote {rel} ({content.length} chars)"

def usage : String :=
  "usage: truth export [repoRoot]   regenerate contracts, code and docs (default root: ..)\n" ++
  "       truth version             print the spec versions"

def main : List String → IO UInt32
  | ["export"] => do exportAll ".."; pure 0
  | ["export", root] => do exportAll root; pure 0
  | ["version"] => do
    IO.println s!"zone {Truth.Zone.specVersion}"
    IO.println s!"health {Truth.Health.specVersion}"
    pure 0
  | _ => do IO.eprintln usage; pure 1
