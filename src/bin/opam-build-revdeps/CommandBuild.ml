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
  let chn = open_out_bin output in
  Marshal.to_channel chn results [];
  close_out chn
