
open CalendarLib
open ReverseDependencies

type e =
  {
    uuid: string;
    package: string;
    result: [`OK|`KO|`DependsKO|`RootPackageKO];
    output_deps: string option;
    time_deps_seconds: int;
    output_build: string option;
    time_build_seconds: int;
  }

let () =
  let ocaml_version = ref "4.03.0" in
  let root_dir =
    ref (FilePath.concat (FileUtil.pwd ()) "_build/test-opam-build-revdeps")
  in
  let package = ref None in
  let only = ref None in
  let exclude = ref SetString.empty in
  let dry_run = ref false in
  let output = ref "output.bin" in
  let () =
    let open Arg in
    parse
      (align
         [
           "--ocaml_version",
           Set_string ocaml_version,
           "ver OCaml version to use.";

           "--root_dir",
           Set_string root_dir,
           "dir Directory where OPAM roots will be stored.";

           "--package",
           String (fun s -> package := Some s),
           "package OPAM package to start with.";

           "--only",
           String
             (fun s ->
                match !only with
                | Some st -> only := Some (SetString.add s st)
                | None -> only := Some (SetString.singleton s)),
           "pkg Only consider this set of packages as a reverse dependency.";

           "--exclude",
           String
             (fun s -> exclude := SetString.add s !exclude),
           "pkg Exclude this set of packages from installation.";

           "--dry_run",
           Set dry_run,
           " Don't do anything, just show what should be done.";

           "--output",
           Set_string output,
           "fn Results output file.";
         ])
      (fun s -> failwith (Printf.sprintf "Don't know what to do with %S." s))
      "test-opam-build-revdeps build reverse dependencies for a given package."
  in
  let opamroot = Filename.concat !root_dir "opam" in

  let package_opt, package_atom =
    match !package with
    | Some s ->
      begin
        match OpamPackage.of_string_opt s with
        | Some p ->
          `Package p, (OpamPackage.name p, Some (`Eq, OpamPackage.version p))
        | None ->
          let n = OpamPackage.Name.of_string s in
          `Name n, (n, None)
      end
    | None -> failwith "You need to specify a package with --package."
  in

  let pristine_repository = 
    {
      PristineRepository.
      opamroot_pristine = Filename.concat !root_dir "opam.pristine";
      opamconf = Filename.concat !root_dir "opamrc";
      ocaml_version = !ocaml_version;
    }
  in

  let () =
    (* Init global variables for OPAM. *)
    OpamGlobals.root_dir := opamroot;
    OpamGlobals.yes := true;

    (* Setup environment. *)
    PristineRepository.init ~dry_run:!dry_run pristine_repository
  in

  let state = OpamState.load_state "reverse_dependencies" in
  let universe_depends = OpamState.universe state OpamTypes.Depends in

  let root_package, excluded_packages =
    let open OpamTypes in
    let nv, all_versions =
      match package_opt with
      | `Package p ->
        p,
        OpamPackage.packages_of_name
          universe_depends.u_packages
          (OpamPackage.name p)
      | `Name n ->
        OpamPackage.max_version universe_depends.u_installed n,
        OpamPackage.packages_of_name universe_depends.u_packages n
    in
    nv,
    OpamPackage.Set.fold
      (fun nv st -> SetString.add (OpamPackage.to_string nv) st)
      (OpamPackage.Set.remove nv all_versions)
      !exclude
  in

  let rev_deps =
    OpamGlobals.note
      "Computing reverse dependencies for package %s"
      (OpamPackage.to_string root_package);
    OpamGlobals.note
      "Excluded packages: %s."
      (String.concat ", " (SetString.elements excluded_packages));
    reverse_dependencies
      {
        only_packages = !only;
        excluded_packages;
        state;
        universe_depends;
        root_package;
      }
  in

  let has_root_package_installed () =
    let state = OpamState.load_state "has_root_installed" in
    let universe_depends = OpamState.universe state OpamTypes.Depends in
    OpamPackage.Set.mem root_package universe_depends.OpamTypes.u_installed
  in

  let install uuid atoms deps success failure =
    let tm = Time.now () in
    let res =
      try
        if not !dry_run then begin
          Printf.printf "start %s\n%!" uuid;
          OpamClient.install atoms None deps;
          Printf.printf "end %s\n%!" uuid;
        end;
        success
      with _ ->
        failure
    in
    res, Time.Period.to_seconds (Time.sub tm (Time.now ()))
  in

  let steps = 2 * (List.length rev_deps) in
  let _, lst =
    List.fold_left
      (fun (n, lst) pkg ->
         let atoms = [atom_eq pkg; atom_eq root_package] in
         let str = OpamPackage.to_string pkg in
         let uuid = Uuidm.to_string (Uuidm.v `V4) in
         let deps_uuid, build_uuid = "deps:"^uuid, "build:"^uuid in
         let result, time_deps_seconds =
           OpamGlobals.note
             "Building dependencies of package %s (%d/%d)." str n steps;
           install deps_uuid atoms true `OK `DependsKO
         in
         let result, time_build_seconds =
           if result = `OK then begin
             OpamGlobals.note "Building package %s (%d/%d)." str (n + 1) steps;
             install build_uuid atoms false `OK `KO
           end else begin
             result, 0
           end
         in
         let result =
           if not (has_root_package_installed ()) then begin
             OpamGlobals.note
               "Requesting install of root package %s."
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
         {
           uuid;
           package = OpamPackage.to_string pkg;
           result;
           output_deps = None;
           time_deps_seconds;
           output_build = None;
           time_build_seconds;
         } :: lst)
      (1, []) rev_deps
  in
  let chn = open_out_bin !output in
  Marshal.to_channel chn lst [];
  close_out chn;
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
    lst
