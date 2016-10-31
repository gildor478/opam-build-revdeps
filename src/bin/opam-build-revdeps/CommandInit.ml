
let run ~dry_run ~root_dir ~ocaml_version () =
  let pristine_repository =
    {
      PristineRepository.
      opamroot_pristine = Filename.concat root_dir "opam.pristine";
      opamconf = Filename.concat root_dir "opamrc";
      ocaml_version = ocaml_version;
    }
  in
  (* Init global variables for OPAM. *)
  OpamGlobals.root_dir := Filename.concat root_dir "opam";
  OpamGlobals.yes := true;
  PristineRepository.init ~dry_run pristine_repository;
