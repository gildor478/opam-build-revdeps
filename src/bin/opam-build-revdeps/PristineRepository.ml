open Utils

type t =
  {
    opamroot_pristine: string;
    opamconf: string;
    ocaml_version: string;
  }

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

(* Restore snapshots if it exists. *)
let restore t =
  let open FileUtil in
  let opamroot = !OpamGlobals.root_dir in
  if test Exists t.opamroot_pristine then begin
    rm_r opamroot;
    cp_r t.opamroot_pristine opamroot;
  end

let init ~dry_run t =
  let opamroot = !OpamGlobals.root_dir in

  restore t;
  (* Setup environment. *)
  if not dry_run then begin
    let fn = OpamPath.state_cache (OpamPath.root ()) in
    if not (OpamFilename.exists fn) then
      OpamClient.init
        (OpamRepository.default ())
        (OpamCompiler.of_string t.ocaml_version)
        ~jobs:1
        `bash
        (OpamFilename.of_string t.opamconf)
        `no;
    OpamClient.update ~repos_only:false [];
    OpamClient.upgrade []
  end;

  (* Dump a snapshot for future use. *)
  rm_r t.opamroot_pristine;
  cp_r opamroot t.opamroot_pristine

