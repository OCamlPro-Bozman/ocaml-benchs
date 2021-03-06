(* The Computer Language Benchmarks Game
   http://benchmarksgame.alioth.debian.org/
   contributed by Milan Stanojevic, Jul 12 2009
   modified to use event channels by Otto Bommer
*)

open Printf

let str2list s = let l=ref [] in String.iter (fun c -> l:=!l@[c]) s; !l

let spell_char = function
  | '0' -> "zero"
  | '1' -> "one"
  | '2' -> "two"
  | '3' -> "three"
  | '4' -> "four"
  | '5' -> "five"
  | '6' -> "six"
  | '7' -> "seven"
  | '8' -> "eight"
  | '9' -> "nine"
  | x -> invalid_arg "unexpected char"

let spell_int i = String.concat " " (List.map spell_char (str2list (string_of_int i)))

module Color = struct
type t = B | R | Y

let complement a b =
match a, b with
  | B, B -> B
  | B, R -> Y
  | B, Y -> R
  | R, B -> Y
  | R, R -> R
  | R, Y -> B
  | Y, B -> R
  | Y, R -> B
  | Y, Y -> Y

let to_string = function B -> "blue" | R -> "red" | Y -> "yellow"

let all = [ B; R; Y ]
end

module Game = struct
type place = {
  mutable meetings_left : int;
  meet : (chameneos Event.channel)
}

and chameneos = {
  mutable color : Color.t;
  mutable meetings : int;
  mutable self_meetings : int;
  morph : ((chameneos * bool) Event.channel);
}

let create_place n = { meetings_left=n; meet=Event.new_channel () }

let create_chameneos color =
  { color=color; meetings=0; self_meetings=0; morph=Event.new_channel () }

let send chn v = Event.sync (Event.send chn v)
let receive chn = Event.sync (Event.receive chn)

let rec run_place place players () = 
  if place.meetings_left > 0 then 
    begin 
    let ch1 = receive place.meet in
    let ch2 = receive place.meet in
    send ch1.morph (ch2, true);
    send ch2.morph (ch1, true);
    place.meetings_left <- place.meetings_left - 1; 
    run_place place players ()
    end
  else
    for i = 0 to players-1 do
      let ch = receive place.meet in 
      send ch.morph (ch, false)
    done

let rec run_chameneos ch place () =
  send place.meet ch;
  let (other, continue) = receive ch.morph in
  if continue then 
    begin
    ch.meetings <- ch.meetings + 1;
    if ch == other then ch.self_meetings <- ch.self_meetings + 1;
    ch.color <- Color.complement ch.color other.color;
    run_chameneos ch place ()
    end

let play colors max_meetings =
  List.iter (fun c -> printf " %s" (Color.to_string c)) colors; printf "\n%!";

  let place = create_place max_meetings in
  let pthread = Thread.create (run_place place (List.length colors)) () in

  let chs = List.map create_chameneos colors in
  let chthreads = List.map (fun ch -> Thread.create (run_chameneos ch place) ()) chs in

  List.iter (fun cht -> Thread.join cht) (pthread::chthreads);

  List.iter (fun ch -> printf "%d %s\n" ch.meetings (spell_int ch.self_meetings)) chs;
  let meetings = List.fold_left (+) 0 (List.map (fun chs -> chs.meetings) chs) in 
  printf " %s\n\n%!" (spell_int meetings)
end

open Color

let print_complements () = List.iter (fun c1 -> List.iter (fun c2 ->
  printf "%s + %s -> %s\n" (to_string c1) (to_string c2)
    (to_string (complement c1 c2)) ) all) all;
  printf "\n"

let _ =
  let max_meetings =
    if Array.length Sys.argv < 2 then 600 else int_of_string Sys.argv.(1) in
  print_complements ();
  Game.play [B; R; Y] max_meetings;
  Game.play [B; R; Y; R; Y; B; R; Y; R; B] max_meetings

let () =
  try
    let fn = Sys.getenv "OCAML_GC_STATS" in
    let oc = open_out fn in
    Gc.print_stat oc
  with _ -> ()
