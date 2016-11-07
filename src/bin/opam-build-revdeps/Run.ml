open Utils
open CalendarLib

type t =
  {
    root_package: string;
    excluded_packages: SetString.t;
    only_packages: SetString.t option;
    packages: Package.t list;
  }

let dump fn (t: t) =
  let chn = open_out_bin fn in
  Marshal.to_channel chn t [];
  close_out chn

let load fn =
  let chn = open_in_bin fn in
  let t: t = Marshal.from_channel chn in
  close_in chn;
  t

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

let build_reverse_dependencies
    ~dry_run
    ~only_packages
    ~excluded_packages
    package =
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
  let _, packages =
    List.fold_left
      (fun (n, lst) nv ->
         let atoms = [atom_eq nv; atom_eq root_package] in
         let e = Package.create nv in
         let open Package in
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
         match e.Package.result with
         | `OK -> "OK"
         | `KO -> "KO"
         | `DependsKO -> "DependsKO"
         | `RootPackageKO -> "RootPackageKO"
       in
       OpamGlobals.note "%s %s" pre e.Package.package)
    packages;
  {
    root_package = package;
    excluded_packages;
    only_packages;
    packages
  }
