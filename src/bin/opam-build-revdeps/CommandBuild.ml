open Utils

type t =
  {
    only: SetString.t option;
    exclude: SetString.t;
    package: Package.t;
  }

let run dry_run init t output =
  let run =
    CommandInit.run dry_run init;
    Run.build_reverse_dependencies
        ~dry_run
        ~only_packages:t.only
        ~excluded_packages:t.exclude
        t.package
  in
  if not dry_run then
    Run.dump output run
