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

type e =
  {
    run_output: string;
    version: Version.t;
    pins: (Package.t * OpamTypes.pin_option) list;
  }

let re_carriage_delete = Re.(compile (rep1 (str "\r\027[K")))

let with_redirect_logs logs_output f =
  let chn = open_out logs_output in
  let finish () = close_out chn in
  let in_fd, out_fd = Unix.pipe () in
  let in_chn = Unix.in_channel_of_descr in_fd in
  try
    let pid = Unix.fork () in
    if pid = 0 then begin
      finish ();
      Unix.dup2 out_fd Unix.stdout;
      Unix.dup2 out_fd Unix.stderr;
      f ();
      exit 0
    end else begin
      Unix.close out_fd;
      begin
        try
          while true do
            let ln = input_line in_chn in
            let ln =
              Re.replace ~all:true re_carriage_delete ~f:(fun _ -> "\n") ln
            in
            print_endline ln;
            output_string chn ln;
            output_string chn "\n";
            flush chn;
          done
        with End_of_file ->
          ()
      end;
      close_in in_chn;
      match snd (Unix.waitpid [] pid) with
      | Unix.WEXITED 0 -> ()
      | Unix.WEXITED n | Unix.WSIGNALED n | Unix.WSTOPPED n ->
        OpamGlobals.error "Forked child has exited with status code %d." n
    end;
    finish ()
  with e ->
    finish ();
    raise e

let run dry_run init build run1 run2 logs_output html =
  let package1, package2 =
    let (n, vopt) as package = build.CommandBuild.package in
    if vopt <> None then
      OpamGlobals.warning
        "The version constraint of root package %s will be replaced."
        (Package.to_string package);
    (n, Some run1.version), (n, Some run2.version)
  in
  let is_better run1 run2 =
    let is_better, lst = Stats.is_better (Stats.compare run1 run2) in
    if lst <> [] then
      OpamGlobals.error "Problematic packages: %s" (String.concat ", " lst);
    is_better
  in
  with_redirect_logs logs_output
    (fun () ->
       CommandBuild.run
        dry_run
        init
        {build with CommandBuild.package = package1}
        run1.run_output
        run1.pins;
      CommandBuild.run
        dry_run
        init
        {build with CommandBuild.package = package2}
        run2.run_output
        run2.pins);
  CommandAttachLogs.run
    dry_run
    [logs_output]
    [run1.run_output; run2.run_output];
  CommandHTML.run
    dry_run
    run1.run_output
    run2.run_output
    html;
  is_better (Run.load run1.run_output) (Run.load run2.run_output)
