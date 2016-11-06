open Utils
open CalendarLib

let opam_package universe s =
  match OpamPackage.of_string_opt s with
  | Some nv -> nv
  | None ->
    let n = OpamPackage.Name.of_string s in
    OpamGlobals.note "Looking up for latest version of %s" s;
    OpamPackage.max_version (OpamSolver.installable universe) n


let has_package_installed nv =
  let state = OpamState.load_state "has_root_installed" in
  let universe_depends = OpamState.universe state OpamTypes.Depends in
  OpamPackage.Set.mem nv universe_depends.OpamTypes.u_installed

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

let dump_list fn (lst: t list) =
  let chn = open_out_bin fn in
  Marshal.to_channel chn lst [];
  close_out chn

let load_list fn =
  let chn = open_in_bin fn in
  let lst: t list = Marshal.from_channel chn in
  close_in chn;
  lst


let build_reverse_dependencies ~dry_run ~only_packages ~excluded_packages package =
  let state = OpamState.load_state "reverse_dependencies" in
  let universe_depends = OpamState.universe state OpamTypes.Depends in
  let root_package = opam_package universe_depends package in

  let rev_deps =
    OpamGlobals.note
      "Computing reverse dependencies for package %s"
      (OpamPackage.to_string root_package);
    ReverseDependencies.reverse_dependencies
      {
        ReverseDependencies.
        only_packages;
        excluded_packages;
        state;
        universe_depends;
        root_package;
      }
  in

  let install uuid atoms deps success failure =
    let tm = Time.now () in
    let res =
      try
        if not dry_run then begin
          Printf.printf "start %s\n%!" uuid;
          OpamClient.install atoms None deps;
          Printf.printf "end %s\n%!" uuid;
        end;
        success
      with _ ->
        failure
    in
    res, Time.Period.to_seconds (Time.sub (Time.now ()) tm)
  in

  let steps = 2 * (List.length rev_deps) in
  let _, results =
    List.fold_left
      (fun (n, lst) nv ->
         let atoms = [atom_eq nv; atom_eq root_package] in
         let e = create nv in
         let result, time_deps_seconds =
           OpamGlobals.note
             "Building dependencies of package %s (%d/%d)." e.package n steps;
           install (deps_uuid e) atoms true `OK `DependsKO
         in
         let result, time_build_seconds =
           if result = `OK then begin
             OpamGlobals.note
               "Building package %s (%d/%d)."
               e.package
               (n + 1)
               steps;
             install (build_uuid e) atoms false `OK `KO
           end else begin
             result, e.time_build_seconds
           end
         in
         let result =
           if not dry_run && not (has_package_installed root_package) then begin
             OpamGlobals.note
               "Requesting reinstall of root package %s."
               (OpamPackage.to_string root_package);
             OpamClient.install [atom_eq root_package] None false;
             if result = `OK then
               `RootPackageKO
             else
               result
           end else begin
             result
           end
         in
         n + 2,
         {e with result; time_deps_seconds; time_build_seconds} :: lst)
      (1, []) rev_deps
  in
  List.iter
    (fun e ->
       let pre =
         match e.result with
         | `OK -> "OK"
         | `KO -> "KO"
         | `DependsKO -> "DependsKO"
         | `RootPackageKO -> "RootPackageKO"
       in
       OpamGlobals.note "%s %s" pre e.package)
    results;
  results
