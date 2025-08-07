(* read XML file and convert it to assembly string *)
let file_xml_to_asm file_xml =
  let program = Minc_parse.file_xml_to_ast file_xml in
  let asm = Minc_cogen.ast_to_asm_program program in
  asm
;;

(* read XML file, convert it to assembly string, and write
   it to a file (file_asm) *)
let file_xml_to_file_asm file_xml file_asm =
  let asm = file_xml_to_asm file_xml in
  let oc = open_out file_asm in
  Printf.fprintf oc "%s" asm; close_out oc
;;

(* entry point 
   ./main.exe fun.xml fun.s 
   read an XML file and generate assembly code in fun.s
*)
let main () =
  let argv = Sys.argv in
  let file_xml = argv.(1) in
  let file_asm = argv.(2) in
  let _ = file_xml_to_file_asm file_xml file_asm in
  0
;;

let () = exit (main ())
;;

