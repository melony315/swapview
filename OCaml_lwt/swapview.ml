type swap_t = (string * int * string) (*pid, size, comm*)

let is_pid (file:string) : bool =
    try ignore (int_of_string file); true
    with _ -> false

let filesize (size:int) : string =
    let rec aux = function
        | (size, []) when size < 1100. -> Printf.sprintf "%.0fB" size
        | (size, []) -> aux (size /. 1024., ["KiB"; "MiB"; "GiB"; "TiB"])
        | (size, h :: []) -> Printf.sprintf "%.1f%s" size h
        | (size, h :: _) when size < 1100. -> Printf.sprintf "%.1f%s" size h
        | (size, _ :: t) -> aux (size /. 1024., t)
    in aux (float_of_int size, [])

let read_dir (dir:string) : string list Lwt.t =
    Lwt_unix.files_of_directory dir
    |> Lwt_stream.to_list

let read_file (filename:string) : string list Lwt.t =
    try%lwt
        let read ic =
            Lwt_io.read_lines ic
            |> Lwt_stream.to_list
        in Lwt_io.with_file Lwt_io.Input filename read
    with _ -> Lwt.return []

let chop_null (s:string) : string =
    let len = String.length s in
    let ss = if (len <> 0) && (s.[len - 1] = '\000')
        then String.sub s 0 (len - 1)
        else s
    in
    String.map (function '\000' -> ' ' | x -> x) ss

let get_comm_for (pid:string) : string Lwt.t =
    match%lwt read_file ("/proc/" ^ pid ^ "/cmdline") with
        | h :: _ -> Lwt.return (chop_null h)
        | _ -> Lwt.return ""

let get_swap_for (pid:string) : swap_t Lwt.t =
    match%lwt read_file ("/proc/" ^ pid ^ "/smaps") with
        | [] -> Lwt.return (pid, 0, "")
        | lines ->
            List.filter (fun line -> String.sub line 0 5 = "Swap:") lines
            |> List.map (fun line ->
                let len = (String.rindex line ' ') - 5 in
                String.sub line 5 len
                |> String.trim
                |> int_of_string)
            |> List.fold_left (fun acc x -> acc + x) 0
            |> fun swap -> (
                let%lwt comm = get_comm_for pid in
                Lwt.return (pid, swap * 1024, comm))

let get_swaps () : swap_t list Lwt.t =
    let open Lwt.Infix in
    read_dir "/proc"
    >|= List.filter is_pid
    >>= fun pids -> Lwt_list.map_p get_swap_for pids
    >|= List.filter (fun (_, s, _) -> (s <> 0))
    >|= List.sort (fun (_,a,_) (_,b,_) -> compare a b)

let%lwt main =
    let print' = Lwt_io.printf "%5s %9s %s\n" in
    let print_swap (pid, swap, comm) = print' pid (filesize swap) comm in
    let print_total total = Lwt_io.printf "Total: %8s\n" (filesize total) in

    let%lwt swaps = get_swaps () in
    let total = List.fold_left (fun acc (_, x, _) -> acc + x) 0 swaps in

    let%lwt _ = print' "PID" "SWAP" "COMMAND" in
    let%lwt _ = Lwt_list.iter_s print_swap swaps in
    let%lwt _ = print_total total in

    Lwt.return_unit
