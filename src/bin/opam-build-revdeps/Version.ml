type t = [`Latest | `Penultimate | `OpamPackageVersion of OpamPackage.Version.t]

let default = `Latest

let parse str =
  match str with
  | "latest" -> `Latest
  | "penultimate" -> `Penultimate
  | ver -> `OpamPackageVersion (OpamPackage.Version.of_string ver)

let to_string =
  function
  | `Latest -> "latest"
  | `Penultimate -> "penultimate"
  | `OpamPackageVersion v -> OpamPackage.Version.to_string v

let to_opam_package universe n t =
  let set () =
    OpamPackage.packages_of_name (OpamSolver.installable universe) n
  in
  let max set =
    let nv = OpamPackage.Set.max_elt set in
    nv, OpamPackage.Set.remove nv set
  in
  match t with
  | `Latest -> fst (max (set ()))
  | `Penultimate -> fst (max (snd (max (set ()))))
  | `OpamPackageVersion v -> OpamPackage.create n v
