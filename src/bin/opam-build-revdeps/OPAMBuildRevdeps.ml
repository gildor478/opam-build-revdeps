open Utils

let () =
  let ocaml_version = ref "4.03.0" in
  let root_dir =
    ref (FilePath.concat (FileUtil.pwd ()) "_build/test-opam-build-revdeps")
  in
  let package_opt = ref None in
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
           String (fun s -> package_opt := Some s),
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

  let package =
    match !package_opt with
    | Some s -> s
    | None -> failwith "You need to specify a package with --package."
  in

  (* Setup environment. *)
  CommandBuild.run
    ~dry_run:!dry_run
    ~root_dir:!root_dir
    ~ocaml_version:!ocaml_version
    ~only_packages:!only
    ~excluded_packages:!exclude
    ~output:!output
    package

