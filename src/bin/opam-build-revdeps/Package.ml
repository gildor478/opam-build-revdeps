type step =
  {
    logs: string option;
    time_seconds: int;
  }

type t =
  {
    uuid: string;
    package: string;
    result: [`OK|`KO|`DependsKO|`RootPackageKO];
    depends: step;
    build: step;
  }


let deps_uuid e = "deps:"^e.uuid
let build_uuid e = "build:"^e.uuid

let create nv =
  let default_step =
    {
      logs= None;
      time_seconds= -1;
    }
  in
  {
    uuid = Uuidm.to_string (Uuidm.v `V4);
    package = OpamPackage.to_string nv;
    result = `KO;
    depends = default_step;
    build = default_step;
  }

