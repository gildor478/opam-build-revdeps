
module OpamClient = OpamClient.SafeAPI

module SetString = Set.Make(String)

let note = OpamGlobals.note

(* TODO: fileutils >= 0.5.0 *)
let cp_r d1 d2 =
  let cmd = Printf.sprintf "cp -r -p %s %s" d1 d2 in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith
      (Printf.sprintf "Command '%s' exited with code %d" cmd exit_code)


(* TODO: fileutils >= 0.5.0 *)
let rm_r d =
  let cmd = Printf.sprintf "rm -rf %s" (Filename.quote d) in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith
      (Printf.sprintf "Command '%s' exited with code %d" cmd exit_code)

type t =
  {
    only_packages: SetString.t option;
    exclude_packages: SetString.t;
    state: OpamState.Types.t;
    universe_depends: OpamTypes.universe;
    root_package: OpamPackage.t;
  }


type e =
  {
    uuid: string;
    package: string;
    result: [`OK|`KO|`DependsKO];
    output: string option;
  }


let reverse_dependencies t =
  let is_included_in st nv =
    let n_str = OpamPackage.Name.to_string (OpamPackage.name nv) in
    let nv_str = OpamPackage.to_string nv in
    SetString.mem n_str st || SetString.mem nv_str st
  in

  let is_not_excluded_on_cli nv =
    not (is_included_in t.exclude_packages nv)
  in

  let is_not_filtered_on_cli nv =
    match is_not_excluded_on_cli nv, t.only_packages with
    | false, _ -> false
    | true, Some st -> is_included_in st nv
    | true, None -> true
  in

  let installable =
    OpamPackage.Set.filter
      (fun nv ->
         if is_not_excluded_on_cli nv then begin
           let opam = OpamState.opam t.state nv in
           OpamFilter.eval_to_bool
             ~default:false
             (OpamState.filter_env ~opam t.state)
             (OpamFile.OPAM.available opam)
         end else begin
           false
         end)
      (OpamSolver.installable t.universe_depends)
  in

  let is_all_depends_installable nv =
    let deps =
      OpamSolver.dependencies
        ~build:true
        ~depopts:false
        ~installed:false
        t.universe_depends
        (OpamPackage.Set.singleton nv)
    in
    let uninstallable_deps =
      List.fold_left
        (fun st nv' ->
           let n' = OpamPackage.name nv' in
           if OpamPackage.Set.mem nv' installable then begin
             OpamPackage.Name.Set.remove n' st
           end else begin
             st
           end)
        (OpamPackage.names_of_packages (OpamPackage.Set.of_list deps))
        deps
    in
    if OpamPackage.Name.Set.is_empty uninstallable_deps then begin
      OpamGlobals.note
        "All dependencies can be installed for package %s."
        (OpamPackage.to_string nv);
      true
    end else begin
      OpamGlobals.note
        "Uninstallable dependencies for package %s: %s."
        (OpamPackage.to_string nv)
        (OpamPackage.Name.Set.to_string uninstallable_deps);
      false
    end
  in

  let is_dependent_on deps opam =
    let formula = OpamTypesBase.filter_deps (OpamFile.OPAM.depends opam) in
    let depends_on nv =
      let name = OpamPackage.name nv in
      let v = OpamPackage.version nv in
      List.exists (fun (n,_) -> name = n) (OpamFormula.atoms formula) &&
      OpamFormula.eval
        (fun (n, cstr) ->
           n <> name ||
           OpamFormula.eval
             (fun (relop, vref) -> OpamFormula.eval_relop relop v vref)
             cstr)
        formula
    in
    OpamPackage.Set.for_all depends_on deps
  in

  let rev_deps =
    let pkg_set = OpamPackage.Set.singleton t.root_package in
    OpamPackage.Set.filter
      (fun nv ->
         if is_not_filtered_on_cli nv then begin
           let opam = OpamState.opam t.state nv in
           if is_dependent_on pkg_set opam then
             is_all_depends_installable nv
           else
             false
         end else begin
           false
         end)
      installable
  in
  OpamPackage.Set.elements rev_deps


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
  let opamroot_pristine = Filename.concat !root_dir "opam.pristine" in
  let opamconf = Filename.concat !root_dir "opamrc" in

  let dump_snapshot () =
    rm_r opamroot_pristine;
    cp_r opamroot opamroot_pristine
  in
  let restore_snapshot () =
    let open FileUtil in
    if test Exists opamroot_pristine then begin
      rm_r opamroot;
      cp_r opamroot_pristine opamroot;
    end
  in

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

  let () =
    (* Init global variables for OPAM. *)
    OpamGlobals.root_dir := opamroot;
    OpamGlobals.yes := true;

    (* Setup environment. *)
    FileUtil.mkdir ~parent:true opamroot;
    restore_snapshot ();
    if not !dry_run then begin
      if not (OpamFilename.exists (OpamPath.state_cache (OpamPath.root ()))) then
        OpamClient.init
          (OpamRepository.default ())
          (OpamCompiler.of_string !ocaml_version)
          ~jobs:1
          `bash
          (OpamFilename.of_string opamconf)
          `no;
      OpamClient.update ~repos_only:false [];
      OpamClient.upgrade []
    end;
    OpamClient.install [package_atom] None false;
    dump_snapshot ()
  in

  let state = OpamState.load_state "reverse_dependencies" in
  let universe_depends = OpamState.universe state OpamTypes.Depends in

  let root_package =
    match package_opt with
    | `Package p -> p
    | `Name n ->
      OpamPackage.max_version universe_depends.OpamTypes.u_installed n
  in

  let rev_deps =
    OpamGlobals.note
      "Computing reverse dependencies for package %s"
      (OpamPackage.to_string root_package);
    reverse_dependencies
      {
        only_packages = !only;
        exclude_packages = !exclude;
        state;
        universe_depends;
        root_package;
      }
  in
  let steps = 2 * (List.length rev_deps) in
  let _, lst =
    List.fold_left
      (fun (n, lst) pkg ->
         let atom = OpamPackage.name pkg, Some (`Eq, OpamPackage.version pkg) in
         let str = OpamPackage.to_string pkg in
         let uuid = Uuidm.to_string (Uuidm.v `V4) in
         let deps_uuid, build_uuid = "deps:"^uuid, "build:"^uuid in
         let result =
           try
             note "Building dependencies of package %s (%d/%d)." str n steps;
             if not !dry_run then begin
               Printf.printf "start %s\n%!" deps_uuid;
               OpamClient.install [atom] None true;
               Printf.printf "end %s\n%!" deps_uuid;
             end;
             `OK
           with _ ->
             `DependsKO
         in
         let result =
           if result = `OK then
             try
               note "Building package %s (%d/%d)." str (n + 1) steps;
               if not !dry_run then begin
                 Printf.printf "start %s\n%!" build_uuid;
                 OpamClient.install [atom] None false;
                 Printf.printf "end %s\n%!" build_uuid
               end;
               `OK
             with _ ->
               `KO
           else
             result
         in
         n + 2,
         {
           uuid;
           package = OpamPackage.to_string pkg;
           result;
           output = None
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
       in
       note "%s %s" pre e.package)
    lst
