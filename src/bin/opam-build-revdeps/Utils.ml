
let atom_eq nv = OpamPackage.name nv, Some (`Eq, OpamPackage.version nv)

module SetString = Set.Make(String)
module OpamClient = OpamClient.SafeAPI
