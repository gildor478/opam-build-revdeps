type e =
  {
    run_output: string;
    version: Version.t;
  }

let with_redirect_logs logs_output f =
  let chn = open_out logs_output in
  let chn_mutex = Mutex.create () in
  let redirect print_eol =
    let in_fd, out_fd = Unix.pipe () in
    let in_chn = Unix.in_channel_of_descr in_fd in
    out_fd,
    Thread.create
      (fun () ->
         begin
           try
             while true do
               let ln = input_line in_chn in
               print_eol ("[redirect] "^ln);
               Mutex.lock chn_mutex;
               output_string chn ln;
               output_string chn "\n";
               Mutex.unlock chn_mutex
             done
           with End_of_file ->
             ()
         end;
         close_in in_chn)
      ()
  in
  let stdout_fd, thread_stdout = redirect print_endline in
  let stderr_fd, thread_stderr = redirect prerr_endline in
  let finish () = close_out chn in
  try
    let pid = Unix.fork () in
    if pid = 0 then begin
      finish ();
      Unix.dup2 stdout_fd Unix.stdout;
      Unix.dup2 stderr_fd Unix.stderr;
      f ();
      exit 0
    end else begin
      Unix.close stdout_fd;
      Unix.close stderr_fd;
      Thread.join thread_stdout;
      Thread.join thread_stderr;
      match snd (Unix.waitpid [] pid) with
      | Unix.WEXITED 0 -> ()
      | Unix.WEXITED n | Unix.WSIGNALED n | Unix.WSTOPPED n ->
        OpamGlobals.error "Forked child has exited with status code %d." n
    end;
    finish ()
  with e ->
    finish ();
    raise e

let run dry_run init build run1 run2 logs_output html_output =
  let package1, package2 =
    let (n, vopt) as package = build.CommandBuild.package in
    if vopt <> None then
      OpamGlobals.warning
        "The version constraint of root package %s will be replaced."
        (Package.to_string package);
    (n, Some run1.version), (n, Some run2.version)
  in
  with_redirect_logs logs_output
    (fun () ->
       CommandBuild.run
        dry_run
        init
        {build with CommandBuild.package = package1}
        run1.run_output;
      CommandBuild.run
        dry_run
        init
        {build with CommandBuild.package = package2}
        run2.run_output);
  CommandAttachLogs.run
    dry_run
    [logs_output]
    [run1.run_output; run2.run_output];
  CommandHTML.run
    dry_run
    run1.run_output
    run2.run_output
    html_output;
  Stats.is_better
    (Stats.compare (Run.load run1.run_output) (Run.load run2.run_output))
