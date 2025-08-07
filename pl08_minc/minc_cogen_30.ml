open Minc_ast

(* A map from a variable name (string) to its stack offset (int) *)
module Env = Map.Make(String)

(* Helper function: joins a list of strings with newlines *)
let join_lines lines = String.concat "\n" lines

(* Helper function: checks if an expression is complex (has nested operations) *)
let rec is_complex_expr expr =
  match expr with
  | ExprOp(_, args) -> List.exists is_complex_expr args
  | ExprCall(_, args) -> List.exists is_complex_expr args
  | ExprParen e -> is_complex_expr e
  | _ -> false

(* Global counter for generating unique labels *)
let label_counter = ref 0

(* Register names for function arguments *)
let param_regs = ["x0"; "x1"; "x2"; "x3"; "x4"; "x5"; "x6"; "x7"]
let gen_label prefix =
  incr label_counter;
  Printf.sprintf ".L%s_%d" prefix !label_counter

(* Label stack for break/continue *)
let break_stack = ref []
let continue_stack = ref []

let push_loop_labels break_label continue_label =
  break_stack := break_label :: !break_stack;
  continue_stack := continue_label :: !continue_stack

let pop_loop_labels () =
  match !break_stack, !continue_stack with
  | _::bs, _::cs -> 
      break_stack := bs;
      continue_stack := cs
  | _ -> failwith "Loop label stack underflow"

let get_current_break_label () =
  match !break_stack with
  | label::_ -> label
  | [] -> failwith "break outside of loop"

let get_current_continue_label () =
  match !continue_stack with
  | label::_ -> label
  | [] -> failwith "continue outside of loop"

(* Compiles an expression. The result is placed in the x0 register. *)
let rec cogen_expr params env asm_rev expr =
  match expr with
  | ExprIntLiteral n ->
      (Printf.sprintf "  mov x0, #%Ld" n) :: asm_rev
  | ExprId name ->
      let param_index = try List.mapi (fun i (_, n) -> if n = name then i else -1) params |> List.find (fun x -> x >= 0)
                       with Not_found -> -1 in
      let offset = if param_index >= 0 then
                    if param_index < List.length param_regs then
                      (* 最初の8個の引数は sp + 56, 48, 40, 32, 24, 16, 8, 0 の順で保存されている *)
                      56 - (param_index * 8)
                    else
                      (* 8個以降の引数は sp + 64 から8バイトずつ上に積まれている *)
                      64 + ((param_index - List.length param_regs) * 8)
                  else
                    Env.find name env in
      (* 適切なレジスタに読み込み *)
      let reg = if param_index >= 0 then
                  if param_index = 0 then "x1"  (* 左辺はx1に *)
                  else "x0"  (* 右辺はx0に *)
                else
                  "x0" in
      (Printf.sprintf "  ldr %s, [sp, #%d]" reg offset) :: asm_rev
  | ExprParen e ->
      cogen_expr params env asm_rev e
  | ExprCall(func_expr, args) ->
      (* 1. Evaluate all arguments from right to left and push their results to the stack. *)
      let push_arg_code =
        List.fold_left
          (fun acc_asm arg ->
            let asm' = cogen_expr params env acc_asm arg in
            "  str x0, [sp, #-16]!" :: asm' (* Push result, maintain 16-byte alignment *)
          )
          asm_rev
          (List.rev args) (* Process from right to left *)
      in

      (* 2. Pop arguments into registers and adjust stack for remaining args *)
      let arg_regs = ["x0"; "x1"; "x2"; "x3"; "x4"; "x5"; "x6"; "x7"] in
      let num_args_in_regs = min (List.length args) (List.length arg_regs) in
      let num_stack_args = List.length args - num_args_in_regs in
      let stack_adjustment = if num_stack_args > 0 then num_stack_args * 16 else 0 in
      
      (* First, load register arguments *)
      let pop_to_regs_code =
        List.fold_left
          (fun acc_asm i ->
            let reg = List.nth arg_regs i in
            (Printf.sprintf "  ldr %s, [sp], #16" reg) :: acc_asm
          )
          push_arg_code
          (List.init num_args_in_regs (fun i -> i))
      in
      
      (* Then, adjust stack pointer to point to the first stack argument *)
      let adjusted_code = 
        if stack_adjustment > 0 then
          (Printf.sprintf "  sub sp, sp, #%d" stack_adjustment) :: pop_to_regs_code
        else
          pop_to_regs_code
      in
      
      (* 3. For arguments beyond the 8th, they remain on the stack. *)

      (* 4. Perform the call. *)
      let call_code = 
        match func_expr with
        | ExprId(func_name) -> (Printf.sprintf "  bl %s" func_name) :: adjusted_code
        | _ -> 
            let asm' = cogen_expr params env adjusted_code func_expr in
            "  blr x0" :: asm'
      in
      
      (* 5. After the call, deallocate arguments that were passed on the stack. *)
      if stack_adjustment > 0 then
        (Printf.sprintf "  add sp, sp, #%d" stack_adjustment) :: call_code
      else
        call_code
        
  | ExprOp(op, args) ->
      (match op, args with
      | "=", [ExprId name; right_expr] ->
          let param_index = try List.mapi (fun i (_, n) -> if n = name then i else -1) params |> List.find (fun x -> x >= 0)
                           with Not_found -> -1 in
          let offset = if param_index >= 0 then
                        if param_index < List.length param_regs then
                          (* 最初の8個の引数は sp + 56, 48, 40, 32, 24, 16, 8, 0 の順で保存されている *)
                          56 - (param_index * 8)
                        else
                          (* 8個以降の引数は sp + 64 から8バイトずつ上に積まれている *)
                          64 + ((param_index - List.length param_regs) * 8)
                      else
                        Env.find name env in
          let asm' = cogen_expr params env asm_rev right_expr in
          let base_reg = if param_index >= 0 then "sp" else "x29" in
          (Printf.sprintf "  str x0, [%s, #%d]" base_reg offset) :: asm'
      
      | "-", [arg] ->
          let asm' = cogen_expr params env asm_rev arg in
          "  neg x0, x0" :: asm'
      
      | "!", [arg] ->
          let asm' = cogen_expr params env asm_rev arg in
          let asm'' = "  cmp x0, #0" :: asm' in
          "  cset w0, eq" :: asm''
      
      | ("+" | "*" | "-" | "/" | "%") as bin_op, [left; ExprIntLiteral n] ->
          let asm' = cogen_expr params env asm_rev left in
          let op_asm = match bin_op with
            | "+" -> [(Printf.sprintf "  add x0, x0, #%Ld" n)]
            | "*" -> [(Printf.sprintf "  mov x1, #%Ld" n); "  mul x0, x0, x1"]
            | "-" -> [(Printf.sprintf "  sub x0, x0, #%Ld" n)]
            | "/" -> [(Printf.sprintf "  mov x1, #%Ld" n); "  sdiv x0, x0, x1"]
            | "%" -> ["  sub x0, x1, x0"; "  mul x0, x2, x0"; "  sdiv x2, x1, x0"]
            | _ -> []
          in
          List.fold_right (fun inst acc -> inst :: acc) op_asm asm'
          
      | ("+" | "*" | "-" | "/" | "%") as bin_op, [left; right] ->
          (* 1. 左辺(left)を評価し、結果をx1に入れる *)
          let asm_for_left = cogen_expr params env asm_rev left in
          let asm_mov = "  mov x1, x0" :: asm_for_left in
          (* 2. 右辺(right)を評価し、結果をx0に入れる *)
          let asm_for_right = cogen_expr params env asm_mov right in
          (* 3. x1 (左辺の結果) と x0 (右辺の結果) で演算する *)
          let op_asm = match bin_op with
            | "+" -> ["  add x0, x1, x0"]
            | "*" -> ["  mul x0, x1, x0"]
            | "-" -> ["  sub x0, x1, x0"]
            | "/" -> ["  sdiv x0, x1, x0"]
            | "%" -> ["  sub x0, x1, x0"; "  mul x0, x2, x0"; "  sdiv x2, x1, x0"]
            | _ -> []
          in
          List.fold_right (fun inst acc -> inst :: acc) op_asm asm_for_right
          
      | ("<" | ">" | "<=" | ">=" | "==" | "!=") as cmp_op, [left; right] ->
          let asm' = cogen_expr params env asm_rev left in
          let asm''' = cogen_expr params env asm' right in
          let asm_cmp = "  cmp x1, x0" :: asm''' in
          let cond = match cmp_op with
            | "<" -> "lt" | ">" -> "gt" | "<=" -> "le"
            | ">=" -> "ge" | "==" -> "eq" | "!=" -> "ne"
            | _ -> ""
          in
          (Printf.sprintf "  cset w0, %s" cond) :: asm_cmp
          
      | "&&", [left; right] ->
          let false_label = gen_label "and_false" in
          let end_label = gen_label "and_end" in
          let asm' = cogen_expr params env asm_rev left in
          let asm'' = "  cmp x0, #0" :: asm' in
          let asm''' = (Printf.sprintf "  beq %s" false_label) :: asm'' in
          let asm4 = cogen_expr params env asm''' right in
          let asm5 = "  cmp x0, #0" :: asm4 in
          let asm6 = (Printf.sprintf "  beq %s" false_label) :: asm5 in
          let asm7 = "  mov x0, #1" :: asm6 in
          let asm8 = (Printf.sprintf "  b %s" end_label) :: asm7 in
          let asm9 = (Printf.sprintf "%s:" false_label) :: asm8 in
          let asm10 = "  mov x0, #0" :: asm9 in
          (Printf.sprintf "%s:" end_label) :: asm10
          
      | "||", [left; right] ->
          let true_label = gen_label "or_true" in
          let end_label = gen_label "or_end" in
          let asm' = cogen_expr params env asm_rev left in
          let asm'' = "  cmp x0, #0" :: asm' in
          let asm''' = (Printf.sprintf "  bne %s" true_label) :: asm'' in
          let asm4 = cogen_expr params env asm''' right in
          let asm5 = "  cmp x0, #0" :: asm4 in
          let asm6 = (Printf.sprintf "  bne %s" true_label) :: asm5 in
          let asm7 = "  mov x0, #0" :: asm6 in
          let asm8 = (Printf.sprintf "  b %s" end_label) :: asm7 in
          let asm9 = (Printf.sprintf "%s:" true_label) :: asm8 in
          let asm10 = "  mov x0, #1" :: asm9 in
          (Printf.sprintf "%s:" end_label) :: asm10
          
      | _ -> failwith ("Unsupported operator or arguments: " ^ op))


(* Compiles a statement *)
let rec cogen_stmt params env return_label asm_rev stmt =
  match stmt with
  | StmtEmpty -> asm_rev
  | StmtContinue ->
      let continue_label = get_current_continue_label () in
      (Printf.sprintf "  b %s" continue_label) :: asm_rev
  | StmtBreak ->
      let break_label = get_current_break_label () in
      (Printf.sprintf "  b %s" break_label) :: asm_rev
  | StmtExpr expr ->
      let _ = cogen_expr params env asm_rev expr in
      asm_rev
  | StmtReturn expr ->
      let asm' = cogen_expr params env asm_rev expr in
      (Printf.sprintf "  b %s" return_label) :: asm'
  | StmtCompound (_, stmts) ->
      List.fold_left (fun acc_asm s -> cogen_stmt params env return_label acc_asm s) asm_rev stmts
  | StmtIf (cond, then_stmt, else_opt) ->
      let else_label = gen_label "if_else" in
      let end_label = gen_label "if_end" in
      let asm' = cogen_expr params env asm_rev cond in
      let asm'' = "  cmp x0, #0" :: asm' in
      let asm''' = (Printf.sprintf "  beq %s" else_label) :: asm'' in
      let asm4 = cogen_stmt params env return_label asm''' then_stmt in
      let asm5 = (Printf.sprintf "  b %s" end_label) :: asm4 in
      let asm6 = (Printf.sprintf "%s:" else_label) :: asm5 in
      let asm7 = match else_opt with
        | Some else_stmt -> cogen_stmt params env return_label asm6 else_stmt
        | None -> asm6 in
      (Printf.sprintf "%s:" end_label) :: asm7
  | StmtWhile (cond, body) ->
      let loop_label = gen_label "while_loop" in
      let end_label = gen_label "while_end" in
      push_loop_labels end_label loop_label;
      let asm' = (Printf.sprintf "%s:" loop_label) :: asm_rev in
      let asm'' = cogen_expr params env asm' cond in
      let asm''' = "  cmp x0, #0" :: asm'' in
      let asm4 = (Printf.sprintf "  beq %s" end_label) :: asm''' in
      let asm5 = cogen_stmt params env return_label asm4 body in
      let asm6 = (Printf.sprintf "  b %s" loop_label) :: asm5 in
      let asm7 = (Printf.sprintf "%s:" end_label) :: asm6 in
      pop_loop_labels ();
      asm7


(* Recursively traverses the statement tree to find all local variable declarations *)
let rec find_all_decls_stmt stmt =
  match stmt with
  | StmtCompound (decls, stmts) ->
      decls @ List.concat (List.map find_all_decls_stmt stmts)
  | StmtIf (_, then_stmt, else_opt) ->
      let then_decls = find_all_decls_stmt then_stmt in
      let else_decls = match else_opt with
        | Some s -> find_all_decls_stmt s
        | None -> []
      in
      then_decls @ else_decls
  | StmtWhile (_, body) ->
      find_all_decls_stmt body
  | _ -> []


(* Compiles a top-level definition (i.e., a function) *)
let cogen_def def =
  match def with
  | DefFun (name, params, _, body) ->
      let local_decls = find_all_decls_stmt body in
      let all_vars = (List.map snd params) @ (List.map snd local_decls) in
      let env, stack_size =
        let env, var_bytes =
          List.fold_left
            (fun (env, offset) var_name ->
              let new_offset = offset - 8 in
              (Env.add var_name new_offset env, new_offset))
            (Env.empty, 0)
            all_vars in
        (env, ((abs var_bytes) + 15) / 16 * 16)
      in
      
      let asm_rev = ref [] in
      let emit str = asm_rev := str :: !asm_rev in

      emit (Printf.sprintf ".global %s" name);
      emit (Printf.sprintf ".type %s, %%function" name);
      emit (Printf.sprintf "%s:" name);
      emit ".cfi_startproc";

      let min_stack_size = if List.length params <= List.length param_regs then
                          max 16 stack_size
                        else
                          64 in
      emit (Printf.sprintf "  sub sp, sp, #%d" min_stack_size);
      emit "  mov x29, sp";  (* フレームポインタを設定 *)

      
                List.iteri (fun i (_, _) ->
            if i < List.length param_regs then
              let reg = List.nth param_regs i in
              (* 最初の8個の引数は sp + 56, 48, 40, 32, 24, 16, 8, 0 の順で保存 *)
              let offset = 56 - (i * 8) in
              emit (Printf.sprintf "  str %s, [sp, #%d]" reg offset)
          ) params;

      let return_label = Printf.sprintf ".L_epilogue_%s" name in
      asm_rev := cogen_stmt params env return_label !asm_rev body;

      emit (Printf.sprintf "%s:" return_label);
      emit (Printf.sprintf "  add sp, sp, #%d" min_stack_size);
      emit "  ret";
      
      emit ".cfi_endproc";
      emit (Printf.sprintf ".size %s, .-%s" name name);
      
      join_lines (List.rev !asm_rev)

(* Entry point: converts a program's AST to an assembly code string *)
let ast_to_asm_program program =
  match program with
  | Program(defs) ->
      let header = [
        "  .arch armv8-a";
        "  .text";
        "  .align 2"
      ] in
      let asm_defs = List.map cogen_def defs in
      let footer = [
        "  .section .note.GNU-stack,\"\",@progbits";
        ""
      ] in
      join_lines (header @ asm_defs @ footer)