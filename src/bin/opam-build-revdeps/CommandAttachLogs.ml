open Utils

let re_uuid =
  let nxdigit n = Re.(repn xdigit n (Some n)) in
  Re.(seq [nxdigit 8; char '-';
           nxdigit 4; char '-';
           nxdigit 4; char '-';
           nxdigit 4; char '-';
           nxdigit 12])
let re_step = Re.(seq [alt [str "deps"; str "build"]; char ':'; re_uuid])
let re_start = Re.(compile (seq [str "start "; group re_step]))
let re_end = Re.(compile (seq [str "end "; group re_step]))

let parse_line ln =
  match Re.exec_opt re_start ln with
  | Some grps ->
    `Start (Re.Group.get grps 1)
  | None ->
    match Re.exec_opt re_end ln with
    | Some grps ->
      `End (Re.Group.get grps 1)
    | None ->
      `Line ln

let parse mp fn =
  let rmp = ref mp in
  let chn = open_in fn in
  let cur_id = ref None in
  let cur_buf = Buffer.create 13 in
  let rec flush id_opt =
    match !cur_id, id_opt with 
    | Some id, None ->
      rmp := MapString.add id (Buffer.contents cur_buf) !rmp;
      Buffer.clear cur_buf;
      cur_id := None
    | Some id, Some id' when id = id' ->
      flush None
    | Some _, Some id' ->
      flush None;
      flush (Some id')
    | None, Some id ->
      rmp := MapString.add id "" !rmp
    | None, None -> ()
  in
  let finish () =
    flush None;
    close_in chn;
    !rmp
  in
  try
    while true do
      match parse_line (input_line chn) with
      | `Start id ->
        begin
          OpamGlobals.note "Found start of log for %s." id;
          flush None;
          cur_id := Some id
        end
      | `Line ln -> Buffer.add_string cur_buf ln; Buffer.add_char cur_buf '\n'
      | `End id ->
        begin
          OpamGlobals.note "Found end of log for %s." id;
          flush (Some id)
        end
    done;
    finish ()
  with End_of_file ->
    finish ()

let run ~dry_run ~logs ~runs () =
  let logs = List.fold_left parse MapString.empty logs in
  let unattached_logs =
    ref (SetString.of_list (List.rev_map fst (MapString.bindings logs)))
  in
  let report_incomplete run =
    let open Run in
    let open Package in
    let missing_deps, missing_build =
      List.fold_left
        (fun (deps_lst, build_lst) e ->
           (if e.output_deps = None then e.package :: deps_lst else deps_lst),
           if e.output_build = None then e.package :: build_lst else build_lst)
        ([], [])
        run.packages
    in
    if missing_deps <> [] then
      OpamGlobals.note
        "Missing dependencies logs for the following packages in run %s: %s."
        run.root_package
        (String.concat ", " missing_deps);
    if missing_build <> [] then
      OpamGlobals.note
        "Missing build logs for the following packages in run %s: %s."
        run.root_package
        (String.concat ", " missing_build)
  in
  let find_log id dflt =
    try
      unattached_logs := SetString.remove id !unattached_logs;
      Some (MapString.find id logs)
    with Not_found ->
      dflt
  in
  let attach_logs_to_run run =
    let packages = run.Run.packages in
    let packages' =
      List.map
        (fun e ->
           let open Package in
           {e with
            output_deps = find_log (deps_uuid e) e.output_deps;
            output_build = find_log (build_uuid e) e.output_build})
        packages
    in
    {run with Run.packages = packages'}
  in
  List.iter
    (fun run_fn ->
       let run = Run.load run_fn in
       let run' = attach_logs_to_run run in
       if not dry_run && run <> run' then begin
         Run.dump run_fn run'
       end;
       report_incomplete run')
    runs;
  if not (SetString.is_empty !unattached_logs) then
    OpamGlobals.note
      "Unattached logs for the following identifiers: %s."
      (SetString.to_string !unattached_logs)






