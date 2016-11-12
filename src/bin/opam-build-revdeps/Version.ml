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

type t = [`Latest | `Penultimate | `OpamPackageVersion of OpamPackage.Version.t]

let default = `Latest

let parse str =
  match str with
  | "latest" -> `Latest
  | "penultimate" -> `Penultimate
  | ver -> `OpamPackageVersion (OpamPackage.Version.of_string ver)

let to_string =
  function
  | `Latest -> "latest"
  | `Penultimate -> "penultimate"
  | `OpamPackageVersion v -> OpamPackage.Version.to_string v

let to_opam_package universe n t =
  let set () =
    OpamPackage.packages_of_name (OpamSolver.installable universe) n
  in
  let max set =
    let nv = OpamPackage.Set.max_elt set in
    nv, OpamPackage.Set.remove nv set
  in
  match t with
  | `Latest -> fst (max (set ()))
  | `Penultimate -> fst (max (snd (max (set ()))))
  | `OpamPackageVersion v -> OpamPackage.create n v
