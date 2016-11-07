let run
    ~dry_run
    ~root_dir
    ~ocaml_version
    ~only_packages
    ~excluded_packages
    ~output
    package =
  let run =
    CommandInit.run ~dry_run ~root_dir ~ocaml_version ();
    Run.build_reverse_dependencies
        ~dry_run
        ~only_packages
        ~excluded_packages
        package
  in
  if not dry_run then
    Run.dump output run
