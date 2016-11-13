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

type step =
  {
    logs: string option;
    time_seconds: int;
  }

type t =
  {
    uuid: string;
    package: string;
    result: [`OK|`KO|`DependsKO|`RootPackageKO];
    depends: step;
    build: step;
  }


let deps_uuid e = "deps:"^e.uuid
let build_uuid e = "build:"^e.uuid

let create nv =
  let default_step =
    {
      logs= None;
      time_seconds= -1;
    }
  in
  {
    uuid = Uuidm.to_string (Uuidm.v `V4);
    package = OpamPackage.to_string nv;
    result = `KO;
    depends = default_step;
    build = default_step;
  }

