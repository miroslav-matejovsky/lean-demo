import Truth

open Truth.Export

/-- Every artifact derived from the spec, relative to the repository root. -/
def artifacts : List (String × String) := [
  ("contracts/order/manifest.json", manifestJson.pretty ++ "\n"),
  ("contracts/order/vectors.json", vectorsJson.pretty (width := 200) ++ "\n"),
  ("impl/dotnet/src/Orders/Generated/Contract.g.cs", csharp),
  ("impl/go/orders/contract_gen.go", golang),
  ("docs/reference/order-state-machine.md", stateMachineDoc)
]

def exportAll (root : System.FilePath) : IO Unit := do
  for (rel, content) in artifacts do
    let path := root / rel
    if let some dir := path.parent then IO.FS.createDirAll dir
    IO.FS.writeFile path content
    IO.println s!"  wrote {rel} ({content.length} chars)"

def usage : String :=
  "usage: truth export [repoRoot]   regenerate contracts, code and docs (default root: ..)\n" ++
  "       truth version             print the spec version"

def main : List String → IO UInt32
  | ["export"] => do exportAll ".."; pure 0
  | ["export", root] => do exportAll root; pure 0
  | ["version"] => do IO.println Truth.Order.specVersion; pure 0
  | _ => do IO.eprintln usage; pure 1
