open Utils
open Package

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

type t = (Status.t * Package.t option * Package.t option) MapString.t

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
