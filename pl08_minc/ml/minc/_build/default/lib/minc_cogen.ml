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
 * cogen_expr: 式（Expression）のコード生成を行う、再帰関数
 *
 * このコンパイラの心臓部の一つ。ASTの「式」ノードを受け取り、
 * その値を計算して結果を常に `x0` レジスタに格納するアセンブリコードを生成します。
 *
 * @param params 現在の関数の仮引数リスト
 * @param env 現在のスコープの環境（変数名 -> スタックオフセット）
 * @param asm_rev これまで生成したアセンブリコードのリスト（逆順）
 * @param expr コード生成の対象となる式のASTノード
 * @return 生成された命令を追加した、新しいアセンブリコードのリスト（逆順）
 *)
let rec cogen_expr params env asm_rev expr =
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
                      (* 【注意: バグあり】このオフセット計算は、cogen_defでの引数保存方法と整合性が取れていません。*)
                      56 - (param_index * 8)
                    else
                      64 + ((param_index - List.length param_regs) * 8)
                  else
                    Env.find name env in
      (* 【注意: バグあり】このロジックは、関数の最初の引数を `x1` に、その他を `x0` にロードしようとします。*)
      (* これは後続の二項演算のロジックと整合性が取れておらず、バグの原因となります。*)
      let reg = "x0" in
      (* 【注意: バグあり】ベースレジスタとして `sp` を使っていますが、関数内でspが変化するとアドレスがずれます。*)
      (* 本来は不動の `x29` を使うべきです。 *)
      (Printf.sprintf "  ldr %s, [sp, #%d]" reg offset) :: asm_rev

  (* ケース3: カッコ式。カッコは評価順序を変えるだけなので、中身を再帰的に評価する。 *)
  | ExprParen e ->
      cogen_expr params env asm_rev e

  (* ケース4: 関数呼び出し。ABI（Application Binary Interface）の規約に従う必要がある。 *)
  | ExprCall(func_expr, args) ->
      (* 1. ABIの規約に基づき、引数を右から左の順で評価し、スタックに積んでいく。 *)
      let push_arg_code =
        List.fold_left
          (fun acc_asm arg ->
            let asm' = cogen_expr params env acc_asm arg in
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
            let asm' = cogen_expr params env adjusted_code func_expr in
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
                          56 - (param_index * 8)
                        else
                          64 + ((param_index - List.length param_regs) * 8)
                      else
                        Env.find name env in
          let asm' = cogen_expr params env asm_rev right_expr in
          (* 【注意: バグあり】引数の場合、ベースレジスタとして `sp` を使っているため、アドレスがずれる可能性があります。*)
          let base_reg = "x29" in
          (Printf.sprintf "  str x0, [%s, #%d]" base_reg offset) :: asm'

      (* ケース5-2: 単項演算子（符号反転、否定）*)
      | "-", [arg] ->
          let asm' = cogen_expr params env asm_rev arg in
          "  neg x0, x0" :: asm'
      
      | "!", [arg] ->
          let asm' = cogen_expr params env asm_rev arg in
          let asm'' = "  cmp x0, #0" :: asm' in
          (* 【注意】`w0` (32ビット) に結果をセットしていますが、MinCの仕様では`long` (64ビット) が要求されるため、`x0` を使うのがより正確です。*)
          (* 修正しました。 *)
          "  cset x0, eq" :: asm''

      (* ケース5-3: 右辺が数値リテラルの二項演算。（最適化）*)
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

      (* ケース5-4: 一般的な二項演算。*)
      | ("+" | "*" | "-" | "/" | "%") as bin_op, [left; right] ->
          (* 【注意: バグあり】この方式は「レジスタ破壊」という重大なバグを引き起こします。*)
          (* 1. 左辺を評価。結果がx0に入ることを期待。しかしExprIdのバグでx1に入ることも。*)
          let asm_for_left = cogen_expr params env asm_rev left in
          (* 2. 左辺の結果をx1に退避。ExprIdのバグでx0が不定値の場合、x1の値が壊れる。*)
          let asm_mov = "  mov x1, x0" :: asm_for_left in
          (* 3. 右辺を評価。この処理の中でx1が上書きされる可能性がある。*)
          let asm_for_right = cogen_expr params env asm_mov right in
          (* 4. x1(左辺の結果)とx0(右辺の結果)で演算するが、x1の値が保証されない。*)
          let op_asm = match bin_op with
            | "+" -> ["  add x0, x1, x0"]
            | "*" -> ["  mul x0, x1, x0"]
            | "-" -> ["  sub x0, x1, x0"]
            | "/" -> ["  sdiv x0, x1, x0"]
            | "%" -> ["  sub x0, x1, x0"; "  mul x0, x2, x0"; "  sdiv x2, x1, x0"]
            | _ -> []
          in
          List.fold_right (fun inst acc -> inst :: acc) op_asm asm_for_right
          
      (* ケース5-5: 比較演算。算術演算と同様のバグを抱えています。*)
      | ("<" | ">" | "<=" | ">=" | "==" | "!=") as cmp_op, [left; right] ->
          let asm' = cogen_expr params env asm_rev left in
          let asm_mov = "  mov x1, x0" :: asm' in               (* x0 → x1 に退避 *)
          let asm''' = cogen_expr params env asm_mov right in    (* 右辺 → x0 *)
          let asm_cmp = "  cmp x1, x0" :: asm''' in            (* x1(左辺) と x0(右辺) を比較 *)
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

(*
 * cogen_stmt: 文（Statement）のコード生成を行う、再帰関数
 *
 * 式(expression)と違い、文(statement)は必ずしも値を返さない。
 * プログラムの制御（if, while, returnなど）を司る。
 *)
let rec cogen_stmt params env return_label asm_rev stmt =
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
      (* 【注意: 重大なバグあり】`cogen_expr`が返した命令リストを`_`で捨ててしまっているため、*)
      (* この文のために生成されたアセンブリコードが結果に含まれません。*)
      let _ = cogen_expr params env asm_rev expr in
      asm_rev

  (* return文。式を評価し、関数の末尾（エピローグ）にジャンプする。*)
  | StmtReturn expr ->
      let asm' = cogen_expr params env asm_rev expr in
      (Printf.sprintf "  b %s" return_label) :: asm'

  (* 複合文 { ... }。中の文を順番に処理する。*)
  | StmtCompound (_, stmts) ->
      List.fold_left (fun acc_asm s -> cogen_stmt params env return_label acc_asm s) asm_rev stmts

  (* if文。条件を評価し、結果に応じて分岐する。*)
  | StmtIf (cond, then_stmt, else_opt) ->
      let else_label = gen_label "if_else" in
      let end_label = gen_label "if_end" in
      let asm' = cogen_expr params env asm_rev cond in
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
      (* 条件式を評価 *)
      let asm'' = cogen_expr params env asm' cond in
      let asm''' = "  cmp x0, #0" :: asm'' in
      (* 条件がfalse (0) なら、ループを抜けてend_labelにジャンプ *)
      let asm4 = (Printf.sprintf "  beq %s" end_label) :: asm''' in
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
      let min_stack_size = if List.length params <= List.length param_regs then
                          max 16 stack_size
                        else
                          64 in
      emit (Printf.sprintf "  sub sp, sp, #%d" min_stack_size);
      emit "  mov x29, sp";

      (* 3. レジスタで渡された引数を、スタックフレーム内に保存する *)
      List.iteri (fun i (_, _) ->
          if i < List.length param_regs then
            let reg = List.nth param_regs i in
            (* 【注意: 重大なバグあり】`sp` を基準に引数を保存していますが、`x29` を設定した後は `x29` を基準にすべきです。*)
            (* また、`56 - (i * 8)` のような大きな正のオフセットは、確保したスタックフレームの外側を指してしまい、メモリ破壊を引き起こす原因となります。*)
            let offset = 56 - (i * 8) in
            emit (Printf.sprintf "  str %s, [sp, #%d]" reg offset)
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