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

(* TODO: fileutils >= 0.5.0 *)
let cp_r d1 d2 =
  let cmd = Printf.sprintf "cp -r -p %s %s" d1 d2 in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith
      (Printf.sprintf "Command '%s' exited with code %d" cmd exit_code)

(* TODO: fileutils >= 0.5.0 *)
let rm_r d =
  let cmd = Printf.sprintf "rm -rf %s" (Filename.quote d) in
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith
      (Printf.sprintf "Command '%s' exited with code %d" cmd exit_code)

(* Restore snapshots if it exists. *)
let restore t =
  let open FileUtil in
  let opamroot = !OpamGlobals.root_dir in
  if test Exists t.opamroot_pristine then begin
    rm_r opamroot;
    cp_r t.opamroot_pristine opamroot;
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
        `no;
    OpamClient.update ~repos_only:false [];
    OpamClient.upgrade []
  end else if not is_initialized then begin
    failwith "Repository doesn't exists, initialize it first."
  end;

  (* Dump a snapshot for future use. *)
  rm_r t.opamroot_pristine;
  cp_r opamroot t.opamroot_pristine

