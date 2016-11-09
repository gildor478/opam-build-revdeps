open Utils
open Cmdliner

module Converter =
struct
  let package =
    let parse s =
      if s = "" then
        `Error "Impossible to use '' as package name."
      else
        `Ok (Package.parse s)
    in
    let print fmt pkg = Format.fprintf fmt "%s" (Package.to_string pkg) in
    parse, print

  let version =
    let parse s =
      if s = "" then
        `Error "Impossible to use '' as package version."
      else
        `Ok (Version.parse s)
    in
    let print fmt pkg = Format.fprintf fmt "%s" (Version.to_string pkg) in
    parse, print
end


let dry_run_t =
  let doc = " Don't do anything, just show what should be done." in
  Arg.(value
       & flag
       & info ["dry_run"] ~doc)

let init_cmd, init_t =
  let init_t =
    let ocaml_version_t =
      let doc = "OPAM switch version to use." in
      Arg.(value
           & opt string Sys.ocaml_version
           & info ["ocaml_version"] ~docv:"VER" ~doc)
    in
    let root_dir_t =
      let doc = "Directory where OPAM roots will be stored." in
      let default =
        FilePath.make_filename [FileUtil.pwd (); "_build"; Conf.name]
      in
      Arg.(value
           & opt string default
           & info ["root_dir"] ~docv:"DN" ~doc)
    in
    Term.(const
            (fun ocaml_version root_dir ->
               CommandInit.({ocaml_version; root_dir}))
          $ ocaml_version_t $ root_dir_t)
  in
  let doc = "initialize pristine OPAM directories." in
  (Term.(const CommandInit.run $ dry_run_t $ init_t),
   Term.info "init" ~doc),
  init_t

let build_cmd, build_t =
  let build_t =
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
    in
    let exclude_t =
      let doc = "Exclude this set of packages from installation." in
      let t =
        Arg.(value
             & opt_all string []
             & info ["exclude"] ~docv:"PKG" ~doc)
      in
      Term.(const SetString.of_list $ t)
    in
    let package_t =
      let doc = "OPAM package to consider." in
      Arg.(required
           & opt (some Converter.package) None
           & info ["package"] ~docv:"PKG" ~doc)
    in
    Term.(const
            (fun only exclude package ->
               CommandBuild.({only; exclude; package}))
            $ only_t $ exclude_t $ package_t)
  in
  let output_t =
    let doc = "Results output file." in
    Arg.(value
         & opt string "output.bin"
         & info ["output"] ~docv:"FN" ~doc)
  in
  let doc = "build reverse dependencies." in
  (Term.(const CommandBuild.run $ dry_run_t $ init_t $ build_t $ output_t),
   Term.info "build" ~doc),
  build_t

let attach_logs_cmd =
  let logs_t =
    let doc = "Logs file to attach." in
    Arg.(value
         & opt_all file []
         & info ["log"] ~docv:"FN" ~doc)
  in
  let runs_t =
    let doc = "Run result file to attach to." in
    Arg.(value
         & opt_all file []
         & info ["run"] ~docv:"FN" ~doc)
  in
  let doc = "attach logs to results file." in
  Term.(const CommandAttachLogs.run $ dry_run_t $ logs_t $ runs_t),
  Term.info "attach_logs" ~doc

let html_cmd =
  let run1_input_t =
    let doc = "First run result file to analyse." in
    Arg.(required
         & opt (some file) None
         & info ["run1_input"] ~docv:"FN" ~doc)
  in
  let run2_input_t =
    let doc = "Second run result file to analyse." in
    Arg.(required
         & opt (some file) None
         & info ["run2_input"] ~docv:"FN" ~doc)
  in
  let output_t =
    let doc = "HTML output file." in
    Arg.(value
         & opt string "output.html"
         & info ["output"] ~docv:"FN" ~doc)
  in
  let doc = "generate an HTML summary." in
  Term.(const CommandHTML.run
        $ dry_run_t
        $ run1_input_t
        $ run2_input_t
        $ output_t),
  Term.info "html" ~doc

let compare_cmd =
  let mk_args doc_prefix arg_no version_default =
    let run_output_t =
      let doc = doc_prefix ^ " run result file." in
      Arg.(value
           & opt file ("run"^arg_no^".bin")
           & info ["run"^arg_no^"_output"] ~docv:"FN" ~doc)
    in
    let version_t =
      let doc =
        doc_prefix ^ " version of the package to consider."
      in
      Arg.(value
           & opt Converter.version version_default
           & info ["version"^arg_no] ~docv:"{latest,penultimate,VER}" ~doc)
    in
    Term.(const
            (fun run_output version -> CommandCompare.({run_output; version}))
          $ run_output_t
          $ version_t)
  in
  let run1_t = mk_args "First" "1" `Penultimate in
  let run2_t = mk_args "Second" "2" `Latest in
  let html_output_t =
    let doc = "HTML output file." in
    Arg.(value
         & opt string "output.html"
         & info ["html_output"] ~docv:"FN" ~doc)
  in
  let logs_output_t =
    let doc = "Logs output file." in
    Arg.(value
         & opt string "logs.txt"
         & info ["logs_output"] ~docv:"FN" ~doc)
  in
  let doc = "compare two version of a package." in
  let f dry_run init build run1 run2 html_output logs_output =
    if CommandCompare.run dry_run
        init
        build
        run1
        run2
        html_output
        logs_output then
      `Ok ()
    else
      `Error (false, "Second version is not better than first version.")
  in
  Term.(ret
          (const f
           $ dry_run_t
           $ init_t
           $ build_t
           $ run1_t
           $ run2_t
           $ logs_output_t
           $ html_output_t)),
  Term.info "compare" ~doc

let default_cmd =
  let doc = "Compare builds of reverse dependencies for a given package." in
  Term.(ret (const (fun _ -> `Help (`Pager, None)) $ (const ()))),
  Term.info Conf.name ~version:Conf.version ~doc

let cmds =
  [
    init_cmd;
    build_cmd;
    attach_logs_cmd;
    html_cmd;
    compare_cmd;
  ]

let () =
  match Term.eval_choice default_cmd cmds with
  | `Error _ -> exit 1
  | _ -> ()
