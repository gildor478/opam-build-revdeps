open Utils
open Cmdliner

let ocaml_version_t =
  let doc = "OPAM switch version to use." in
  Arg.(value
       & opt string Sys.ocaml_version
       & info ["ocaml_version"] ~docv:"VER" ~doc)


let root_dir_t =
  let doc = "Directory where OPAM roots will be stored." in
  let default = 
    FilePath.make_filename [FileUtil.pwd (); "_build"; Conf.name]
  in
  Arg.(value
       & opt string default
       & info ["root_dir"] ~docv:"DN" ~doc)

let package_t =
  let doc = "OPAM package to consider." in
  Arg.(required
       & opt (some string) None
       & info ["package"] ~docv:"PKG" ~doc)

let only_t =
  let doc = "Only consider this set of packages as a reverse dependency." in
  let t =
    Arg.(value
         & opt_all string []
         & info ["only"] ~docv:"PKG" ~doc)
  in
  Term.(const
          (function
            | [] -> None
            | lst -> Some (SetString.of_list lst)) $ t)

let exclude_t =
  let doc = "Exclude this set of packages from installation." in
  let t =
    Arg.(value
         & opt_all string []
         & info ["exclude"] ~docv:"PKG" ~doc)
  in
  Term.(const SetString.of_list $ t)

let dry_run_t =
  let doc = " Don't do anything, just show what should be done." in
  Arg.(value
       & flag
       & info ["dry_run"] ~doc)

let output_t =
  let doc = "Results output file." in
  Arg.(value
       & opt string "output.bin"
       & info ["output"] ~docv:"FN" ~doc)

let info =
  let doc = "Build reverse dependencies for a given package." in
  Term.info Conf.name ~version:Conf.version ~doc

let build_cmd =
  let f
      dry_run
      root_dir
      ocaml_version
      only_packages
      excluded_packages
      output
      package =
  CommandBuild.run
    ~dry_run
    ~root_dir
    ~ocaml_version
    ~only_packages
    ~excluded_packages
    ~output
    package
  in
  Term.(const f
        $ dry_run_t
        $ root_dir_t
        $ ocaml_version_t
        $ only_t
        $ exclude_t
        $ output_t
        $ package_t)


let () =
  match Term.eval (build_cmd, info) with
  | `Error _ -> exit 1
  | _ -> ()
