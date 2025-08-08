open Minc_ast

(*
 * コンパイラの中核部分: コード生成器 (Code Generator)
 *
 * このファイルは、MinC言語のソースコードが変換された「AST (Abstract Syntax Tree; 抽象構文木)」を
 * 入力として受け取り、それをAArch64（ARM64）アーキテクチャのアセンブリコードに変換する役割を担います。
 * いわば、コンパイラの最終段階です。
 *)

(*
 * Env モジュール (環境; Environment)
 *
 * 変数名（string）から、その変数がメモリ上のどこにいるかを示す「スタックオフセット（int）」への
 * 対応を管理します。Map.Makeを使うことで、効率的な辞書（キーと値のペア）を実現しています。
 * コンパイラの専門用語では「シンボルテーブル (Symbol Table)」に近い役割です。
 *)
module Env = Map.Make(String)

(*
 * join_lines: 文字列リストを改行で連結するヘルパー関数
 *)
let join_lines lines = String.concat "\n" lines

(*
 * is_complex_expr: 式が複雑（入れ子になっている）かどうかを判定するヘルパー関数
 *
 * 例えば「式が単純な場合はスタックを使わず、複雑な場合のみスタックを使う」といった
 * 最適化を実装する際に利用できますが、現在のコードでは使われていません。
 *)
let rec is_complex_expr expr =
  match expr with
  | ExprOp(_, args) -> List.exists is_complex_expr args
  | ExprCall(_, args) -> List.exists is_complex_expr args
  | ExprParen e -> is_complex_expr e
  | _ -> false

(*
 * グローバル変数（カウンタやスタック）
 * コンパイル処理全体で共有されます。
 *)

(* label_counter: ユニークなラベル名を生成するためのカウンタ *)
let label_counter = ref 0
(* param_regs: AArch64の引数渡しで使われるレジスタ名リスト *)
let param_regs = ["x0"; "x1"; "x2"; "x3"; "x4"; "x5"; "x6"; "x7"]

(* 
 * 動的レジスタ割り当てシステム
 * ARM64の豊富なレジスタを活用して入れ子構造に対応
 *)

(* temp_regs: 一時的な計算用レジスタのプール（x9-x15を使用、x8は除外） *)
let temp_regs = ["x9"; "x10"; "x11"; "x12"; "x13"; "x14"; "x15"]

(* get_temp_register: 入れ子の深さに基づいて適切なレジスタを選択 *)
let get_temp_register depth =
  let max_depth = List.length temp_regs in
  if depth < max_depth then
    List.nth temp_regs depth
  else
    (* 深すぎる場合はx15を使い回す（実用的にはスタックが必要） *)
    List.nth temp_regs (max_depth - 1)

(*
 * gen_label: 新しいラベルを生成する
 *
 * アセンブリコードでは、if文やwhile文のジャンプ先を示すために「ラベル」が必要です。
 * (例: .L_if_else_1, .L_while_loop_2)
 * この関数は、被らないように連番を振って新しいラベル名を生成します。
 *)
let gen_label prefix =
  incr label_counter;
  Printf.sprintf ".L%s_%d" prefix !label_counter

(*
 * ループ制御用のラベルスタック
 *
 * whileループが入れ子になった場合、breakやcontinueがどのループを指すのかを
 * 管理する必要があります。スタック構造（後入れ先出し）を使うことで、
 * 「最も内側のループのラベル」を常に取り出すことができます。
 *)
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



(*
 * cogen_expr: 式（Expression）のコード生成を行う、再帰関数（動的レジスタ割り当て対応版）
 *
 * このコンパイラの心臓部の一つ。ASTの「式」ノードを受け取り、
 * その値を計算して結果を常に `x0` レジスタに格納するアセンブリコードを生成します。
 * 入れ子の深さに応じて動的にレジスタを選択し、レジスタ破壊を防ぎます。
 *
 * @param params 現在の関数の仮引数リスト
 * @param env 現在のスコープの環境（変数名 -> スタックオフセット）
 * @param asm_rev これまで生成したアセンブリコードのリスト（逆順）
 * @param depth 現在の式の入れ子深度（0から開始）
 * @param expr コード生成の対象となる式のASTノード
 * @return 生成された命令を追加した、新しいアセンブリコードのリスト（逆順）
 *)
let rec cogen_expr params env asm_rev depth expr =
  match expr with
  (* ケース1: ただの整数。mov命令でx0に即値をセットするだけ。 *)
  | ExprIntLiteral n ->
      (Printf.sprintf "  mov x0, #%Ld" n) :: asm_rev

  (* ケース2: 変数。変数の値をメモリからレジスタにロードする。 *)
  | ExprId name ->
      let param_index = try List.mapi (fun i (_, n) -> if n = name then i else -1) params |> List.find (fun x -> x >= 0)
                       with Not_found -> -1 in
      let offset = if param_index >= 0 then
        if param_index < List.length param_regs then
          -(8 + param_index * 8)  (* 第1-8引数: 負のオフセット *)
        else
          192 + ((param_index - List.length param_regs) * 8)  (* 第9引数以降: 正のオフセット *)
      else
        Env.find name env
      in
      (* 引数は全てx0に入っている。 *)
      let reg = "x0" in
      (* 【注意: バグあり】ベースレジスタとして `sp` を使っていますが、関数内でspが変化するとアドレスがずれます。*)
      (* 本来は不動の `x29` を使うべきです。 *)
      (Printf.sprintf "  ldr %s, [x29, #%d]" reg offset) :: asm_rev

  (* ケース3: カッコ式。カッコは評価順序を変えるだけなので、中身を再帰的に評価する。 *)
  | ExprParen e ->
      cogen_expr params env asm_rev depth e

  (* ケース4: 関数呼び出し。ABI（Application Binary Interface）の規約に従う必要がある。 *)
  | ExprCall(func_expr, args) ->
      (* 1. ABIの規約に基づき、引数を右から左の順で評価し、スタックに積んでいく。 *)
      let push_arg_code =
        List.fold_left
          (fun acc_asm arg ->
            let asm' = cogen_expr params env acc_asm (depth + 1) arg in
            (* 16バイトアライメントを維持しつつ、結果(x0)をスタックにプッシュ *)
            "  str x0, [sp, #-16]!" :: asm'
          )
          asm_rev
          (List.rev args) (* 右から評価するためにリストを反転 *)
      in

      (* 2. 最初の8個の引数を、スタックからレジスタ x0-x7 にポップする。 *)
      let arg_regs = ["x0"; "x1"; "x2"; "x3"; "x4"; "x5"; "x6"; "x7"] in
      let num_args_in_regs = min (List.length args) (List.length arg_regs) in
      let num_stack_args = List.length args - num_args_in_regs in
      let stack_adjustment = if num_stack_args > 0 then num_stack_args * 16 else 0 in
      let pop_to_regs_code =
        List.fold_left
          (fun acc_asm i ->
            let reg = List.nth arg_regs i in
            (Printf.sprintf "  ldr %s, [sp], #16" reg) :: acc_asm
          )
          push_arg_code
          (List.init num_args_in_regs (fun i -> i))
      in
      
      let adjusted_code = 
        if stack_adjustment > 0 then
          (Printf.sprintf "  sub sp, sp, #%d" stack_adjustment) :: pop_to_regs_code
        else
          pop_to_regs_code
      in
      
      (* 3. 関数を呼び出す。bl (Branch with Link)命令を使う。 *)
      let call_code =
        match func_expr with
        | ExprId(func_name) -> (Printf.sprintf "  bl %s" func_name) :: adjusted_code
        | _ ->  (* 関数ポインタ経由の呼び出しなど *)
            let asm' = cogen_expr params env adjusted_code (depth + 1) func_expr in
            "  blr x0" :: asm'
      in
      
      if stack_adjustment > 0 then
        (Printf.sprintf "  add sp, sp, #%d" stack_adjustment) :: call_code
      else
        call_code

  (* ケース5: 演算子を使った式。 *)
  | ExprOp(op, args) ->
      (match op, args with
      (* ケース5-1: 代入。右辺を評価し、左辺の変数のアドレスに結果をストアする。 *)
      | "=", [ExprId name; right_expr] ->
          let param_index = try List.mapi (fun i (_, n) -> if n = name then i else -1) params |> List.find (fun x -> x >= 0)
                           with Not_found -> -1 in
          let offset = if param_index >= 0 then
            if param_index < List.length param_regs then
              -(8 + param_index * 8)  (* 第1-8引数: 負のオフセット *)
            else
              192 + ((param_index - List.length param_regs) * 8)  (* 第9引数以降: 正のオフセット *)
          else
            Env.find name env
          in
          let asm' = cogen_expr params env asm_rev (depth + 1) right_expr in
          (* 【注意: バグあり】引数の場合、ベースレジスタとして `sp` を使っているため、アドレスがずれる可能性があります。*)
          let base_reg = "x29" in
          (Printf.sprintf "  str x0, [%s, #%d]" base_reg offset) :: asm'

      (* ケース5-2: 単項演算子（符号反転、否定）*)
      | "-", [arg] ->
          let asm' = cogen_expr params env asm_rev (depth + 1) arg in
          "  neg x0, x0" :: asm'
      
      | "!", [arg] ->
          let asm' = cogen_expr params env asm_rev (depth + 1) arg in
          let asm'' = "  cmp x0, #0" :: asm' in
          (* 【注意】`w0` (32ビット) に結果をセットしていますが、MinCの仕様では`long` (64ビット) が要求されるため、`x0` を使うのがより正確です。*)
          (* 修正しました。 *)
          "  cset x0, eq" :: asm''

      (* ケース5-3: 右辺が数値リテラルの二項演算。（最適化）*)
      | ("+" | "*" | "-" | "/" | "%") as bin_op, [left; ExprIntLiteral n] ->
          let asm' = cogen_expr params env asm_rev (depth + 1) left in
          let op_asm = match bin_op with
            | "+" -> [(Printf.sprintf "  add x0, x0, #%Ld" n)]
            | "*" -> ["  mul x0, x0, x1"; (Printf.sprintf "  mov x1, #%Ld" n)]
            | "-" -> [(Printf.sprintf "  sub x0, x0, #%Ld" n)]
            | "/" -> ["  sdiv x0, x0, x1"; (Printf.sprintf "  mov x1, #%Ld" n)]
            | "%" -> [
                "  sub x0, x0, x2";                       (* x0 = x0 - x2 (余り) *)
                "  mul x2, x2, x1";                      (* x2 = x2 * x1 *)
                "  udiv x2, x0, x1";                     (* x2 = x0 / x1 (商) *)
                (Printf.sprintf "  mov x1, #%Ld" n)     (* 除数をx1に設定 *)
              ]
            | _ -> []
          in
          List.fold_right (fun inst acc -> inst :: acc) op_asm asm'

      (* ケース5-4: 一般的な二項演算 - 動的レジスタ割り当て版 *)
      | ("+" | "*" | "-" | "/" | "%") as bin_op, [left; right] ->
          (* 入れ子の深さに応じて動的にレジスタを選択 *)
          let temp_reg = get_temp_register depth in
          let asm_for_left = cogen_expr params env asm_rev (depth + 1) left in
          let asm_mov = (Printf.sprintf "  mov %s, x0" temp_reg) :: asm_for_left in
          let asm_for_right = cogen_expr params env asm_mov (depth + 1) right in
          let op_asm = match bin_op with
            | "+" -> [(Printf.sprintf "  add x0, %s, x0" temp_reg)]
            | "*" -> [(Printf.sprintf "  mul x0, %s, x0" temp_reg)]
            | "-" -> [(Printf.sprintf "  sub x0, %s, x0" temp_reg)]
            | "/" -> [(Printf.sprintf "  sdiv x0, %s, x0" temp_reg)]
            | "%" -> [
                (Printf.sprintf "  sub x0, %s, x1" temp_reg);     (* x0 = temp_reg - x1 (余り) *)
                "  mul x1, x1, x0";                               (* x1 = (temp_reg/x0) * x0 *)
                (Printf.sprintf "  udiv x1, %s, x0" temp_reg)   (* x1 = temp_reg / x0 (商) *)
              ]
            | _ -> []
          in
          List.fold_right (fun inst acc -> inst :: acc) op_asm asm_for_right
          
      (* ケース5-5: 比較演算 - 動的レジスタ割り当て版 *)
      | ("<" | ">" | "<=" | ">=" | "==" | "!=") as cmp_op, [left; right] ->
          (* 入れ子の深さに応じて動的にレジスタを選択 *)
          let temp_reg = get_temp_register depth in
          let asm_for_left = cogen_expr params env asm_rev (depth + 1) left in
          let asm_mov = (Printf.sprintf "  mov %s, x0" temp_reg) :: asm_for_left in
          let asm_for_right = cogen_expr params env asm_mov (depth + 1) right in
          let asm_cmp = (Printf.sprintf "  cmp %s, x0" temp_reg) :: asm_for_right in
          let cond = match cmp_op with
            | "<" -> "lt" | ">" -> "gt" | "<=" -> "le"
            | ">=" -> "ge" | "==" -> "eq" | "!=" -> "ne"
            | _ -> ""
          in
          (Printf.sprintf "  cset x0, %s" cond) :: asm_cmp
      
      (* ケース5-6: 論理演算子。短絡評価(short-circuit evaluation)を実装する。*)
      | "&&", [left; right] ->
          let false_label = gen_label "and_false" in
          let end_label = gen_label "and_end" in
          let asm' = cogen_expr params env asm_rev (depth + 1) left in
          let asm'' = "  cmp x0, #0" :: asm' in
          let asm''' = (Printf.sprintf "  beq %s" false_label) :: asm'' in
          let asm4 = cogen_expr params env asm''' (depth + 1) right in
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
          let asm' = cogen_expr params env asm_rev (depth + 1) left in
          let asm'' = "  cmp x0, #0" :: asm' in
          let asm''' = (Printf.sprintf "  bne %s" true_label) :: asm'' in
          let asm4 = cogen_expr params env asm''' (depth + 1) right in
          let asm5 = "  cmp x0, #0" :: asm4 in
          let asm6 = (Printf.sprintf "  bne %s" true_label) :: asm5 in
          let asm7 = "  mov x0, #0" :: asm6 in
          let asm8 = (Printf.sprintf "  b %s" end_label) :: asm7 in
          let asm9 = (Printf.sprintf "%s:" true_label) :: asm8 in
          let asm10 = "  mov x0, #1" :: asm9 in
          (Printf.sprintf "%s:" end_label) :: asm10
          
      | _ -> failwith ("Unsupported operator or arguments: " ^ op))

(*
 * cogen_stmt: 文（Statement）のコード生成を行う、再帰関数
 *
 * 式(expression)と違い、文(statement)は必ずしも値を返さない。
 * プログラムの制御（if, while, returnなど）を司る。
 *)
let rec cogen_stmt params env return_label asm_rev stmt =
  (* 比較演算の最適化: 直接分岐命令を生成 *)
  let optimize_comparison_branch asm_with_label cond end_label =
    match cond with
    | ExprOp(("<" | ">" | "<=" | ">=" | "==" | "!=") as op, [left; right]) ->
        (* 比較演算を直接分岐に変換（mov命令削減版） *)
        let temp_reg = get_temp_register 0 in
        (* 左辺を直接temp_regに読み込み（movを削減） *)
        let asm_for_left = match left with
          | ExprId name ->
              (* 変数の場合は直接temp_regに読み込み *)
              let param_index = try List.mapi (fun i (_, n) -> if n = name then i else -1) params |> List.find (fun x -> x >= 0)
                               with Not_found -> -1 in
              let offset = if param_index >= 0 then
                if param_index < List.length param_regs then
                  -(8 + param_index * 8)
                else
                  192 + ((param_index - List.length param_regs) * 8)
              else
                Env.find name env
              in
              (Printf.sprintf "  ldr %s, [x29, #%d]" temp_reg offset) :: asm_with_label
          | _ ->
              (* その他の場合は従来通り *)
              let asm_for_left = cogen_expr params env asm_with_label 1 left in
              (Printf.sprintf "  mov %s, x0" temp_reg) :: asm_for_left
        in
        let asm_for_right = cogen_expr params env asm_for_left 1 right in
        let asm_cmp = (Printf.sprintf "  cmp %s, x0" temp_reg) :: asm_for_right in
        (* 条件を反転して、falseの場合にend_labelへジャンプ *)
        let branch_op = match op with
          | "<" -> "bge"   (* >= なら終了 *)
          | ">" -> "ble"   (* <= なら終了 *)
          | "<=" -> "bgt"  (* > なら終了 *)
          | ">=" -> "blt"  (* < なら終了 *)
          | "==" -> "bne"  (* != なら終了 *)
          | "!=" -> "beq"  (* == なら終了 *)
          | _ -> "beq"
        in
        Some ((Printf.sprintf "  %s %s" branch_op end_label) :: asm_cmp)
    | _ -> 
        (* 比較演算でない場合は最適化しない *)
        None
  in
  match stmt with
  | StmtEmpty -> asm_rev (* 空の文は何もしない *)
  | StmtContinue ->
      let continue_label = get_current_continue_label () in
      (Printf.sprintf "  b %s" continue_label) :: asm_rev
  | StmtBreak ->
      let break_label = get_current_break_label () in
      (Printf.sprintf "  b %s" break_label) :: asm_rev

  (* 式文。例えば `x = 1;` や `f();` など。結果は使わないが、評価は行う。*)
  | StmtExpr expr ->
      (* 式文では副作用（代入など）が重要なので、生成されたアセンブリコードを返す *)
      cogen_expr params env asm_rev 0 expr

  (* return文。式を評価し、関数の末尾（エピローグ）にジャンプする。*)
  | StmtReturn expr ->
      let asm' = cogen_expr params env asm_rev 0 expr in
      (Printf.sprintf "  b %s" return_label) :: asm'

  (* 複合文 { ... }。中の文を順番に処理する。*)
  | StmtCompound (_, stmts) ->
      List.fold_left (fun acc_asm s -> cogen_stmt params env return_label acc_asm s) asm_rev stmts

  (* if文。条件を評価し、結果に応じて分岐する。*)
  | StmtIf (cond, then_stmt, else_opt) ->
      let else_label = gen_label "if_else" in
      let end_label = gen_label "if_end" in
      let asm' = cogen_expr params env asm_rev 0 cond in
      let asm'' = "  cmp x0, #0" :: asm' in
      (* 条件がfalse (0) なら、else_labelにジャンプ *)
      let asm''' = (Printf.sprintf "  beq %s" else_label) :: asm'' in
      (* then節のコードを生成 *)
      let asm4 = cogen_stmt params env return_label asm''' then_stmt in
      (* then節が終わったら、end_labelにジャンプしてelseをスキップ *)
      let asm5 = (Printf.sprintf "  b %s" end_label) :: asm4 in
      (* else節のコードを生成 *)
      let asm6 = (Printf.sprintf "%s:" else_label) :: asm5 in
      let asm7 = match else_opt with
        | Some else_stmt -> cogen_stmt params env return_label asm6 else_stmt
        | None -> asm6 in
      (Printf.sprintf "%s:" end_label) :: asm7

  (* while文。条件を評価し、ループを続けるか判断する。*)
  | StmtWhile (cond, body) ->
      let loop_label = gen_label "while_loop" in
      let end_label = gen_label "while_end" in
      push_loop_labels end_label loop_label;
      (* ループの開始点 *)
      let asm' = (Printf.sprintf "%s:" loop_label) :: asm_rev in
      (* 比較演算の最適化を試行 *)
      let asm4 = match optimize_comparison_branch asm' cond end_label with
        | Some optimized_asm -> optimized_asm
        | None -> 
            (* 従来の方式（最適化不可能な条件式） *)
            let asm'' = cogen_expr params env asm' 0 cond in
            let asm''' = "  cmp x0, #0" :: asm'' in
            (Printf.sprintf "  beq %s" end_label) :: asm'''
      in
      (* ループ本体のコードを生成 *)
      let asm5 = cogen_stmt params env return_label asm4 body in
      (* ループ本体の最後で、次のループのために先頭に戻る *)
      let asm6 = (Printf.sprintf "  b %s" loop_label) :: asm5 in
      (* ループの終了点 *)
      let asm7 = (Printf.sprintf "%s:" end_label) :: asm6 in
      pop_loop_labels ();
      asm7


(*
 * find_all_decls_stmt: ローカル変数の宣言をすべて見つけるヘルパー関数
 *
 * コード生成を始める前に、関数内でどれくらいのスタック領域が必要になるか計算するため、
 * 先にASTをトラバースして、すべての変数宣言をリストアップする。
 *)
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


(*
 * cogen_def: トップレベルの定義（関数）のコード生成を行う
 *)
let cogen_def def =
  match def with
  | DefFun (name, params, _, body) ->
      (* 1. この関数で使われる全変数（引数＋ローカル変数）のリストアップと、環境(env)の構築 *)
      let local_decls = find_all_decls_stmt body in
      let all_vars = (List.map snd params) @ (List.map snd local_decls) in
      let env, stack_size =
        let env, var_bytes =
          List.fold_left
            (fun (env, offset) var_name ->
              (* 各変数に、フレームポインタx29からの負のオフセットを割り当てる *)
              let new_offset = offset - 8 in
              (Env.add var_name new_offset env, new_offset))
            (Env.empty, 0)
            all_vars in
        (* スタックサイズは16バイトの倍数にアライメントする *)
        (env, ((abs var_bytes) + 15) / 16 * 16)
      in

      let asm_rev = ref [] in
      let emit str = asm_rev := str :: !asm_rev in

      (* --- 関数プロローグ (Function Prologue) --- *)
      (* 関数の開始時に行われるお決まりの処理 *)
      emit (Printf.sprintf ".global %s" name);
      emit (Printf.sprintf ".type %s, %%function" name);
      emit (Printf.sprintf "%s:" name);
      emit ".cfi_startproc";

      (* 2. スタックフレームを確保し、フレームポインタを設定する *)
      let min_stack_size = 
        let param_size = List.length params * 8 in
        let local_size = stack_size in
        ((param_size + local_size + 15) / 16) * 16  (* 16バイトアライメント *)
      in
      emit (Printf.sprintf "  sub sp, sp, #%d" min_stack_size);
      emit "  mov x29, sp";

      (* 3. レジスタで渡された引数を、スタックフレーム内に保存する *)
      List.iteri (fun i (_, _) ->
          if i < List.length param_regs then
            let reg = List.nth param_regs i in
            (* 【注意: 重大なバグあり】`sp` を基準に引数を保存していますが、`x29` を設定した後は `x29` を基準にすべきです。*)
            (* また、`56 - (i * 8)` のような大きな正のオフセットは、確保したスタックフレームの外側を指してしまい、メモリ破壊を引き起こす原因となります。*)
            let offset = -(8 + i * 8) in  (* 負のオフセット *)
            emit (Printf.sprintf "  str %s, [x29, #%d]" reg offset)
        ) params;

      (* --- 関数本体 (Function Body) --- *)
      (* 4. 文のコード生成を開始 *)
      let return_label = Printf.sprintf ".L_epilogue_%s" name in
      asm_rev := cogen_stmt params env return_label !asm_rev body;

      (* --- 関数エピローグ (Function Epilogue) --- *)
      (* 関数の終了時に行われるお決まりの処理 *)
      emit (Printf.sprintf "%s:" return_label);
      (* 5. スタックフレームを解放し、呼び出し元に戻る *)
      emit (Printf.sprintf "  add sp, sp, #%d" min_stack_size);
      emit "  ret";

      emit ".cfi_endproc";
      emit (Printf.sprintf ".size %s, .-%s" name name);

      join_lines (List.rev !asm_rev)

(*
 * ast_to_asm_program: プログラム全体のコード生成のエントリーポイント
 *)
let ast_to_asm_program program =
  match program with
  | Program(defs) ->
      (* アセンブリファイルのヘッダ部分 *)
      let header = [
        "  .arch armv8-a";
        "  .text";
        "  .align 2"
      ] in
      (* 各関数定義を順番にコード生成 *)
      let asm_defs = List.map cogen_def defs in
      (* アセンブリファイルのフッタ部分 *)
      let footer = [
        "  .section .note.GNU-stack,\"\",@progbits";
        ""
      ] in
      (* すべてを結合して、一つのアセンブリコード文字列にする *)
      join_lines (header @ asm_defs @ footer)