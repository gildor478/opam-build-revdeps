let run
    ~dry_run
    ~root_dir
    ~ocaml_version
    ~only_packages
    ~excluded_packages
    ~output
    package =
  let results =
    CommandInit.run ~dry_run ~root_dir ~ocaml_version ();
    Package.build_reverse_dependencies
        ~dry_run
        ~only_packages
        ~excluded_packages
        package
  in
  Package.dump_list output results
