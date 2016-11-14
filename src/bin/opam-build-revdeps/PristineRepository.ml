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

type t =
  {
    opamroot_pristine: string;
    opamconf: string;
    ocaml_version: string;
  }

(* Restore snapshots if it exists. *)
let restore t =
  let open FileUtil in
  let opamroot = !OpamGlobals.root_dir in
  if test Exists t.opamroot_pristine then begin
    rm ~recurse:true [opamroot];
    cp ~recurse:true [t.opamroot_pristine] opamroot;
  end

let init ~dry_run t =
  let opamroot = !OpamGlobals.root_dir in
  let is_initialized =
    OpamFilename.exists (OpamPath.state_cache (OpamPath.root ()))
  in

  restore t;
  (* Setup environment. *)
  if not dry_run then begin
    if not is_initialized then
      OpamClient.init
        (OpamRepository.default ())
        (OpamCompiler.of_string t.ocaml_version)
        ~jobs:1
        `bash
        (OpamFilename.of_string t.opamconf)
        `no
    else
      OpamClient.update ~repos_only:false [];
    OpamClient.SWITCH.switch
      ~quiet:true
      ~warning:false
      (OpamSwitch.of_string t.ocaml_version);
    OpamClient.upgrade []
  end else if not is_initialized then begin
    failwith "Repository doesn't exists, initialize it first."
  end;

  (* Dump a snapshot for future use. *)
  FileUtil.rm ~recurse:true [t.opamroot_pristine];
  FileUtil.cp ~recurse:true [opamroot] t.opamroot_pristine;

