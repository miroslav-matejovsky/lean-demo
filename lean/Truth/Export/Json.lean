/-!
# Minimal JSON writer

Deliberately tiny (no dependency on the `Lean` compiler package) so the
exporter binary stays small and fast to build. Output is stable and
diff-friendly: short values are inlined, long ones are split over lines.
-/

namespace Truth.Export

inductive Json where
  | null
  | bool (b : Bool)
  | num (n : Nat)
  | str (s : String)
  | arr (xs : List Json)
  | obj (kvs : List (String × Json))
  deriving Inhabited

namespace Json

def escape (s : String) : String :=
  s.foldl (init := "") fun acc c =>
    match c with
    | '"' => acc ++ "\\\""
    | '\\' => acc ++ "\\\\"
    | '\n' => acc ++ "\\n"
    | '\r' => acc ++ "\\r"
    | '\t' => acc ++ "\\t"
    | c => acc.push c

partial def compact : Json → String
  | .null => "null"
  | .bool b => toString b
  | .num n => toString n
  | .str s => "\"" ++ escape s ++ "\""
  | .arr xs => "[" ++ ", ".intercalate (xs.map compact) ++ "]"
  | .obj kvs => "{" ++ ", ".intercalate (kvs.map fun (k, v) => s!"\"{escape k}\": {compact v}") ++ "}"

/-- Pretty print: inline when the compact form fits in `width` characters. -/
partial def pretty (j : Json) (indent : Nat := 0) (width : Nat := 110) : String :=
  let c := compact j
  if c.length + indent ≤ width then c else
  let pad := "".pushn ' ' (indent + 2)
  let close := "".pushn ' ' indent
  match j with
  | .arr xs =>
    "[\n" ++ ",\n".intercalate (xs.map fun x => pad ++ pretty x (indent + 2) width) ++ "\n" ++ close ++ "]"
  | .obj kvs =>
    "{\n" ++ ",\n".intercalate (kvs.map fun (k, v) =>
      s!"{pad}\"{escape k}\": " ++ pretty v (indent + 2) width) ++ "\n" ++ close ++ "}"
  | _ => c

end Json

end Truth.Export
