type t =
  {
    uuid: string;
    package: string;
    result: [`OK|`KO|`DependsKO|`RootPackageKO];
    output_deps: string option;
    time_deps_seconds: int;
    output_build: string option;
    time_build_seconds: int;
  }

let deps_uuid e = "deps:"^e.uuid
let build_uuid e = "build:"^e.uuid

let create nv =
  {
    uuid = Uuidm.to_string (Uuidm.v `V4);
    package = OpamPackage.to_string nv;
    result = `KO;
    (* TODO: be consistent, output_deps -> deps.logs + deps.time, same for
       build
     *)
    output_deps = None;
    time_deps_seconds = -1;
    output_build = None;
    time_build_seconds = -1;
  }

