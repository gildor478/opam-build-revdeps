open Utils
open Jg_types
open Package

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
  let deps, build =
    match vopt with
    | None ->
      step None, step None
    | Some e when e.result = `DependsKO  ->
      step (Some e.depends), step None
    | Some e ->
      step (Some e.depends), step (Some e.build)
  in
  let h = Hashtbl.create 2 in
  Hashtbl.add h "deps" deps;
  Hashtbl.add h "build" build;
  Thash h

let run ~dry_run ~run1_input ~run2_input ~output () =
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
  let html =
    Jg_template.from_string
      ~models:[
        "packages", Tlist (List.rev lst);
        "run1", Tobj ["name", Tstr run1.Run.root_package];
        "run2", Tobj ["name", Tstr run2.Run.root_package];
        "is_better", Tbool (Stats.is_better stats);
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
    let chn = open_out_bin output in
    output_string chn html;
    close_out chn
  end

