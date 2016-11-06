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
    | Some id', _ ->
      rmp := MapString.add id' (Buffer.contents cur_buf) !rmp;
      Buffer.clear cur_buf;
      cur_id := None;
      flush id_opt
    | None, Some id -> rmp := MapString.add id "" !rmp
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

let run ~dry_run ~logs ~results () =
  let logs = List.fold_left parse MapString.empty logs in
  let find_log id dflt =
    try
      Some (MapString.find id logs)
    with Not_found ->
      dflt
  in
  let attach_logs_to_result fn =
    let results = Package.load_list fn in
    let results' =
      List.map
        (fun e ->
           let open Package in
           {e with
            output_deps = find_log (deps_uuid e) e.output_deps;
            output_build = find_log (build_uuid e) e.output_build})
        results
    in
    if not dry_run && results <> results' then begin
      Package.dump_list fn results'
    end
  in
  List.iter attach_logs_to_result results






