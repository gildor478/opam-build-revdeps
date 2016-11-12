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
open PackageBuilt

module Status =
struct
  type t = [`OK|`KO|`DependsKO|`RootPackageKO|`AsBad|`Missing]

  let to_string =
    function
    | `OK -> "ok"
    | `KO -> "ko"
    | `DependsKO -> "dependsko"
    | `RootPackageKO -> "rootpackageko"
    | `AsBad -> "asbad"
    | `Missing -> "missing"
end

type t = (Status.t * PackageBuilt.t option * PackageBuilt.t option) MapString.t

let compare run1 run2 =
  let status pkg1 pkg2 =
    match pkg1, pkg2 with
    | Some _, None -> `Missing
    | None, Some pkg2 -> (pkg2.result :> Status.t)
    | None, None -> `AsBad
    | Some _, Some pkg2 when pkg2.result = `OK -> `OK
    | Some pkg1, Some pkg2 when pkg1.result = pkg2.result -> `AsBad
    | Some _, Some pkg2 -> (pkg2.result :> Status.t)
  in
  let mp =
    List.fold_left
      (fun mp pkg1 ->
         MapString.add pkg1.package (Some pkg1, None) mp)
      MapString.empty
      run1.Run.packages
  in
  let mp =
    List.fold_left
      (fun mp pkg2 ->
         let v =
           try
             let pkg1, _ = MapString.find pkg2.package mp in
             pkg1, Some pkg2
           with Not_found ->
             None, Some pkg2
         in
         MapString.add pkg2.package v mp)
      mp
      run2.Run.packages
  in
  MapString.map
    (fun (pkg1, pkg2) ->
       status pkg1 pkg2, pkg1, pkg2)
    mp

let is_better t =
  MapString.for_all
    (fun _ stats ->
       match stats with
       | st, Some _, Some _ -> st = `OK || st = `AsBad
       | _, Some _, None -> false
       | _ -> true)
    t

let count t st =
  MapString.fold (fun _ (st', _, _) c -> if st = st' then c + 1 else c) t 0

let total_packages t = MapString.cardinal t
