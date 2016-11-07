
let atom_eq nv = OpamPackage.name nv, Some (`Eq, OpamPackage.version nv)

module SetString =
struct
  include Set.Make(String)

  let of_list lst = List.fold_left (fun t e -> add e t) empty lst

  let to_string t =
    "{ "^(String.concat ", " (elements t))^" }"
end

module MapString = Map.Make(String)

module OpamClient = OpamClient.SafeAPI
