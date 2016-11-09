type t =
  {
    root_dir: string;
    ocaml_version: string;
  }

let run dry_run t =
  let pristine_repository =
    {
      PristineRepository.
      opamroot_pristine = Filename.concat t.root_dir "opam.pristine";
      opamconf = Filename.concat t.root_dir "opamrc";
      ocaml_version = t.ocaml_version;
    }
  in
  (* Init global variables for OPAM. *)
  FileUtil.mkdir ~parent:true t.root_dir;
  OpamGlobals.root_dir := Filename.concat t.root_dir "opam";
  OpamGlobals.yes := true;
  OpamGlobals.color := false;
  OpamGlobals.dryrun := dry_run;
  PristineRepository.init ~dry_run pristine_repository;
