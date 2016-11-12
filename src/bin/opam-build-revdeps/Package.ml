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

type t = OpamPackage.Name.t * Version.t option

let parse str =
  match OpamPackage.of_string_opt str with
  | Some nv ->
    let ver = OpamPackage.Version.to_string (OpamPackage.version nv) in
    OpamPackage.name nv, Some (Version.parse ver)
  | None -> OpamPackage.Name.of_string str, None

let to_string (n, vopt) =
  let nstr = OpamPackage.Name.to_string n in
  match vopt with
  | Some v -> nstr^"."^(Version.to_string v)
  | None -> nstr

let to_opam_package universe (n, vopt) =
  let v =
    match vopt with
    | Some v -> v
    | None -> Version.default
  in
  Version.to_opam_package universe n v

