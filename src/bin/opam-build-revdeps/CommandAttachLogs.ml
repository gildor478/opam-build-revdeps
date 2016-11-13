(******************************************************************************)
(* opam-build-revdeps: build reverse dependencies of a package in OPAM.       *)
(*                                                                            *)
(* Copyright (C) 2016, Sylvain Le Gall                                        *)
(*                                                                            *)
(* This library is free software; you can redistribute it and/or modify it    *)
(* under the terms of the GNU Lesser General Public License as published by   *)
(* the Free Software Foundation; either version 2.1 of the License, or (at    *)
(* your option) any later version, with the OCaml static compilation          *)
(* exception.                                                                 *)
(*                                                                            *)
(* This library is distributed in the hope that it will be useful, but        *)
(* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY *)
(* or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more         *)
(* details.                                                                   *)
(*                                                                            *)
(* You should have received a copy of the GNU Lesser General Public License   *)
(* along with this library; if not, write to the Free Software Foundation,    *)
(* Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA              *)
(******************************************************************************)

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

let run dry_run logs runs =
  let logs = List.fold_left parse MapString.empty logs in
  let unattached_logs =
    ref (SetString.of_list (List.rev_map fst (MapString.bindings logs)))
  in
  let report_incomplete run =
    let open Run in
    let open PackageBuilt in
    let missing_depends, missing_build =
      List.fold_left
        (fun (depends_lst, build_lst) e ->
           (if e.depends.logs = None then
              e.package :: depends_lst
            else
              depends_lst),
           if e.build.logs = None && e.result <> `DependsKO then
             e.package :: build_lst
           else
             build_lst)
        ([], [])
        run.packages
    in
    if missing_depends <> [] then
      OpamGlobals.note
        "Missing dependencies logs for the following packages in run %s: %s."
        run.root_package
        (String.concat ", " missing_depends);
    if missing_build <> [] then
      OpamGlobals.note
        "Missing build logs for the following packages in run %s: %s."
        run.root_package
        (String.concat ", " missing_build)
  in
  let find_log id dflt =
    try
      unattached_logs := SetString.remove id !unattached_logs;
      {dflt with PackageBuilt.logs = Some (MapString.find id logs)}
    with Not_found ->
      dflt
  in
  let attach_logs_to_run run =
    let packages = run.Run.packages in
    let packages' =
      List.map
        (fun e ->
           let open PackageBuilt in
           {e with
            depends = find_log (deps_uuid e) e.depends;
            build = find_log (build_uuid e) e.build})
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






