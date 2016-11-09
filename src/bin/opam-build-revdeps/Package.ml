type t = OpamPackage.Name.t * Version.t option

let parse str =
  match OpamPackage.of_string_opt str with
  | Some nv ->
    let ver = OpamPackage.Version.to_string (OpamPackage.version nv) in
    OpamPackage.name nv, Some (Version.parse ver)
  | None -> OpamPackage.Name.of_string str, None

let to_string (n, vopt) =
  let nstr = OpamPackage.Name.to_string n in
  match vopt with
  | Some v -> nstr^"."^(Version.to_string v)
  | None -> nstr

let to_opam_package universe (n, vopt) =
  let v =
    match vopt with
    | Some v -> v
    | None -> Version.default
  in
  Version.to_opam_package universe n v

