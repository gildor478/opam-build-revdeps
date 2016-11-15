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
open Jg_types
open PackageBuilt

type t =
  {
    html_output: string;
    css_output: string;
  }

let result vopt =
  let string_of_time d =
    if d > 0 then begin
      let h = d / 3600 in
      let m = (d mod 3600) / 60 in
      let s = d mod 60 in
      match h, m , s  with
      | 0, 0, s -> Printf.sprintf "%ds" s
      | 0, m, s -> Printf.sprintf "%dm %ds" m s
      | h, m, s -> Printf.sprintf "%dh %dm %ds" h m s
    end else begin
      "N/A"
    end
  in
  let step sopt =
    let h = Hashtbl.create 2 in
    let opt f t =
      match t with
      | Some e -> f e
      | None -> "N/A"
    in
    Hashtbl.add h
      "time"
      (Tstr (opt (fun s -> string_of_time s.time_seconds) sopt));
    Hashtbl.add h "logs" (Tstr (opt (fun s -> opt String.trim s.logs) sopt));
    Thash h
  in
  let deps, build, result =
    match vopt with
    | None ->
      step None, step None, "N/A"
    | Some e when e.result = `DependsKO  ->
      step (Some e.depends), step None, Stats.Status.to_string e.result
    | Some e ->
      step (Some e.depends),
      step (Some e.build),
      Stats.Status.to_string e.result
  in
  let h = Hashtbl.create 2 in
  Hashtbl.add h "deps" deps;
  Hashtbl.add h "build" build;
  Hashtbl.add h "result" (Tstr result);
  Thash h

let run dry_run run1_input run2_input t =
  let run1 = Run.load run1_input in
  let run2 = Run.load run2_input in
  let stats = Stats.compare run1 run2 in
  let lst =
    MapString.fold
      (fun k (status, pkg1, pkg2) lst ->
         let h = Hashtbl.create 13 in
         List.iter
           (fun (k, v) -> Hashtbl.add h k v)
           [
             "name", (Tstr k);
             "status", (Tstr (Stats.Status.to_string status));
             "pkg1", result pkg1;
             "pkg2", result pkg2;
           ];
         Thash h :: lst)
      stats []
  in
  let css_output =
    let open FilePath in
    make_relative
      (dirname (make_absolute (FileUtil.pwd ()) t.html_output))
      (make_absolute (FileUtil.pwd ()) t.css_output)
  in
  let is_better, problematic_packages = Stats.is_better stats in
  let problematic_packages = List.map (fun s -> Tstr s) problematic_packages in
  let html =
    Jg_template.from_string
      ~models:[
        "css_output", Tstr css_output;
        "generator_url", Tstr Conf.homepage;
        "generator", Tstr (Conf.name ^ " "  ^ Conf.version);
        "packages", Tlist (List.rev lst);
        "run1", Tobj ["name", Tstr run1.Run.root_package];
        "run2", Tobj ["name", Tstr run2.Run.root_package];
        "is_better", Tbool is_better;
        "problematic_packages", Tlist problematic_packages;
        "count_ok", Tint (Stats.count stats `OK);
        "count_ko", Tint (Stats.count stats `KO);
        "count_dependsko", Tint (Stats.count stats `DependsKO);
        "count_rootpackageko", Tint (Stats.count stats `RootPackageKO);
        "count_asbad", Tint (Stats.count stats `AsBad);
        "count_missing", Tint (Stats.count stats `Missing);
        "total_packages", Tint (Stats.total_packages stats);
      ]
      HTMLTemplates.htmlMain_tmpl
  in
  if not dry_run then begin
    let dump fn str =
      let chn = open_out_bin fn in
      output_string chn str;
      close_out chn
    in
    dump t.html_output html;
    dump t.css_output HTMLTemplates.htmlMain_css
  end

