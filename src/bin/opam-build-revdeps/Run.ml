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
open CalendarLib

type t =
  {
    root_package: string;
    excluded_packages: SetString.t;
    only_packages: SetString.t option;
    packages: PackageBuilt.t list;
  }

let dump fn (t: t) =
  let chn = open_out_bin fn in
  Marshal.to_channel chn t [];
  close_out chn

let load fn =
  let chn = open_in_bin fn in
  let t: t = Marshal.from_channel chn in
  close_in chn;
  t

(* TODO: remove *)
let opam_package universe s =
  match OpamPackage.of_string_opt s with
  | Some nv -> nv
  | None ->
    let n = OpamPackage.Name.of_string s in
    OpamGlobals.note "Looking up for latest version of %s" s;
    OpamPackage.max_version (OpamSolver.installable universe) n


let has_package_installed nv =
  let state = OpamState.load_state "has_root_installed" in
  let universe_depends = OpamState.universe state OpamTypes.Depends in
  OpamPackage.Set.mem nv universe_depends.OpamTypes.u_installed

let build_reverse_dependencies
    ~dry_run
    ~only_packages
    ~excluded_packages
    package =
  let state = OpamState.load_state "reverse_dependencies" in
  let universe_depends = OpamState.universe state OpamTypes.Depends in
  let root_package = Package.to_opam_package universe_depends package in

  let rev_deps =
    OpamGlobals.note
      "Computing reverse dependencies for package %s"
      (OpamPackage.to_string root_package);
    ReverseDependencies.reverse_dependencies
      {
        ReverseDependencies.
        only_packages;
        excluded_packages;
        state;
        universe_depends;
        root_package;
      }
  in

  let install uuid atoms deps step success failure =
    let tm = Time.now () in
    let start_str = "start "^uuid in
    let end_str = "end "^uuid in
    let print_flush s =
      Printf.printf "%s\n%!" s;
      Printf.eprintf "%!"
    in
    let res =
      print_flush start_str;
      try
        OpamClient.install atoms None deps;
        success
      with _ ->
        failure
    in
    print_flush end_str;
    res,
    {step with
     PackageBuilt.time_seconds =
       Time.Period.to_seconds (Time.sub (Time.now ()) tm)}
  in

  let steps = 2 * (List.length rev_deps) in
  let _, packages =
    List.fold_left
      (fun (n, lst) nv ->
         let atoms = [atom_eq nv; atom_eq root_package] in
         let e = PackageBuilt.create nv in
         let open PackageBuilt in
         let result, depends =
           OpamGlobals.note
             "Building dependencies of package %s (%d/%d)." e.package n steps;
           install (deps_uuid e) atoms true e.depends `OK `DependsKO
         in
         let result, build =
           if result = `OK then begin
             OpamGlobals.note
               "Building package %s (%d/%d)."
               e.package
               (n + 1)
               steps;
             install (build_uuid e) atoms false e.build `OK `KO
           end else begin
             result, e.build
           end
         in
         let result =
           if not dry_run && not (has_package_installed root_package) then begin
             OpamGlobals.note
               "Requesting reinstall of root package %s."
               (OpamPackage.to_string root_package);
             OpamClient.install [atom_eq root_package] None false;
             if result = `OK then
               `RootPackageKO
             else
               result
           end else begin
             result
           end
         in
         n + 2,
         {e with result; depends; build} :: lst)
      (1, []) rev_deps
  in
  List.iter
    (fun e ->
       let pre =
         match e.PackageBuilt.result with
         | `OK -> "OK"
         | `KO -> "KO"
         | `DependsKO -> "DependsKO"
         | `RootPackageKO -> "RootPackageKO"
       in
       OpamGlobals.note "%s %s" pre e.PackageBuilt.package)
    packages;
  {
    root_package = OpamPackage.to_string root_package;
    excluded_packages;
    only_packages;
    packages
  }
