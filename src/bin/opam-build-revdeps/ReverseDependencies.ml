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
    only_packages: SetString.t option;
    excluded_packages: SetString.t;
    state: OpamState.Types.t;
    universe_depends: OpamTypes.universe;
    root_package: OpamPackage.t;
  }


let reverse_dependencies t =
  let () =
    OpamGlobals.note
      "Excluded packages: %s."
      (String.concat ", " (SetString.elements t.excluded_packages))
  in

  let is_included_in st nv =
    let n_str = OpamPackage.Name.to_string (OpamPackage.name nv) in
    let nv_str = OpamPackage.to_string nv in
    SetString.mem n_str st || SetString.mem nv_str st
  in

  let is_not_excluded_on_cli nv =
    not (is_included_in t.excluded_packages nv)
  in

  let is_not_filtered_on_cli nv =
    match is_not_excluded_on_cli nv, t.only_packages with
    | false, _ -> false
    | true, Some st -> is_included_in st nv
    | true, None -> true
  in

  let universe =
    let u = t.universe_depends in
    let set_filter = OpamPackage.Set.filter is_not_excluded_on_cli in
    let map_filter mp =
      OpamPackage.Map.filter (fun nv _ -> is_not_excluded_on_cli nv) mp
    in
    let open OpamTypes in
    {
      u_packages = set_filter u.u_packages;
      u_installed = set_filter u.u_installed;
      u_available = set_filter u.u_available;
      u_depends = map_filter u.u_depends;
      u_depopts = map_filter u.u_depopts;
      u_conflicts = map_filter u.u_conflicts;
      u_action = u.u_action;
      u_installed_roots = set_filter u.u_installed_roots;
      u_pinned = set_filter u.u_pinned;
      u_base = set_filter u.u_base;
    }
  in

  let installable =
    OpamPackage.Set.filter
      (fun nv ->
         let opam = OpamState.opam t.state nv in
         OpamFilter.eval_to_bool
           ~default:false
           (OpamState.filter_env ~opam t.state)
           (OpamFile.OPAM.available opam))
      (OpamSolver.installable universe)
  in

  let is_installable nv =
    let open OpamTypes in
    let result =
      OpamSolver.resolve
        ~verbose:true
        universe
        ~orphans:OpamPackage.Set.empty
        {
          wish_install =
            [
              atom_eq nv;
              atom_eq t.root_package;
            ];
          wish_remove = [];
          wish_upgrade = [];
          criteria = `Default;
        }
    in
    match result with
    | Success _ -> true
    | Conflicts _ -> false
  in

  let is_dependent_on deps opam =
    let formula = OpamTypesBase.filter_deps (OpamFile.OPAM.depends opam) in
    let depends_on nv =
      let name = OpamPackage.name nv in
      let v = OpamPackage.version nv in
      List.exists (fun (n,_) -> name = n) (OpamFormula.atoms formula) &&
      OpamFormula.eval
        (fun (n, cstr) ->
           n <> name ||
           OpamFormula.eval
             (fun (relop, vref) -> OpamFormula.eval_relop relop v vref)
             cstr)
        formula
    in
    OpamPackage.Set.for_all depends_on deps
  in

  let rev_deps =
    let pkg_set = OpamPackage.Set.singleton t.root_package in
    OpamPackage.Set.filter
      (fun nv ->
         if is_not_filtered_on_cli nv then begin
           let opam = OpamState.opam t.state nv in
           if is_dependent_on pkg_set opam then begin
             let nv_str = OpamPackage.to_string nv in
             let installable =
               OpamGlobals.note
                 "Considering installability of package %s"
                 nv_str;
               is_installable nv
             in
             if installable then
               OpamGlobals.note "Package %s will be built." nv_str
             else
               OpamGlobals.note "Package %s is not installable." nv_str;
             installable
           end else
             false
         end else begin
           false
         end)
      installable
  in
  OpamPackage.Set.elements rev_deps

