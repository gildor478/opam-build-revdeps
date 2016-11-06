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
  let step time logs =
    let h = Hashtbl.create 2 in
    let opt f t =
      let v =
        match t with
        | Some e -> f e
        | None -> "N/A"
      in
      Tstr v
    in
    Hashtbl.add h "time" (opt string_of_time time);
    Hashtbl.add h "logs" (opt (fun s -> s) logs);
    Thash h
  in
  let deps, build =
    match vopt with
    | None ->
      step None None, step None None
    | Some e when e.result = `DependsKO  ->
      step (Some e.time_deps_seconds) e.output_deps, step None None
    | Some e ->
      step (Some e.time_deps_seconds) e.output_deps,
      step (Some e.time_build_seconds) e.output_build
  in
  let h = Hashtbl.create 2 in
  Hashtbl.add h "deps" deps;
  Hashtbl.add h "build" build;
  Thash h

let run ~dry_run ~run1_input ~run2_input ~output () =
  (* TODO: add a module Run. *)
  let run1 = Package.load_list run1_input in
  let run2 = Package.load_list run2_input in
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
        "results", Tlist (List.rev lst);
        "run1", Tobj ["name", Tstr "oasis.0.4.6"];
        "run2", Tobj ["name", Tstr "oasis.0.4.7"];
        "is_better", Tbool (Stats.is_better stats);
        "count_ok", Tint (Stats.count stats `OK);
        "count_as_bad", Tint (Stats.count stats `AsBad);
        "total_packages", Tint (Stats.total_packages stats);
      ]
      HTMLTemplates.htmlMain_tmpl
  in
  if not dry_run then begin
    let chn = open_out_bin output in
    output_string chn html;
    close_out chn
  end

