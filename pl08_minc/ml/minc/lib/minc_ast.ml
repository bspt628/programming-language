(* Abstract Syntax Tree *)

(* type expression:

   for now, we only have a primitive type (long),
   which is TypePrimitive("long") *)
type type_expr =
  TypePrimitive of string
;;

(* variable declaration:

   long x; -> (TypePrimitive("long"), "x")
   also (ab)used to represent a function parameter *)
type decl = type_expr * string
;;

(* expression *)
type expr =
  ExprIntLiteral of int64        (* 1, 2, 3, ... *)
| ExprId of string               (* x, y, z, ... *)
| ExprOp of (string * expr list) (* -x, x - y, ... *)
| ExprCall of (expr * expr list) (* f(1, 2, 3) *)
| ExprParen of expr              (* (x + y) *)
;;

(* statement *)
type stmt = 
  StmtEmpty                     (* ; *)
| StmtContinue                  (* continue; *)
| StmtBreak                     (* break; *)
| StmtReturn of expr            (* return e; *)
| StmtExpr of expr              (* f(x); *)
| StmtCompound of (decl list * stmt list) (* { int x; return x + 1; } *)
| StmtIf of (expr * stmt * stmt option)   (* if (expr) stmt [else stmt] *)
| StmtWhile of (expr * stmt)              (* while (expr) stmt *)
;;

(* toplevel definition *)
type def =
  (* function definition
     e.g., long f(long x, long y) { return x; } ->
     DefFun("f", 
            [(TypePrimitive("long"), "x"); (TypePrimitive("long"), "y")], 
            TypePrimitive("long"), 
            StmtCompound([], [StmtReturn(ExprId("x"))]))
 *)
  DefFun of (string * decl list * type_expr * stmt) 
;;

(* program is just a list of definitions *)
type program =
  Program of (def list)
;;

(* convert ast back to C string 
   
   ast_to_str_xxx converts an AST to a string 
   valid as a C program.

   it will not be used anywhere in your compiler, 
   but is given for illustrating how you walk
   the AST and what kind of C program each AST 
   is actually meant to represent.
*)

(* AST for type expression -> C string
   TypePrimitive("long") -> "long" *)
let ast_to_str_type type_expr =
  match type_expr with
    TypePrimitive(s) -> s
;;

(* AST for function parameter -> C string
   (TypePrimitive("long"), "x") -> "long x" *)
let ast_to_str_param (param_type, name) =
  Printf.sprintf "%s %s" (ast_to_str_type param_type) name
;;

(* AST for a variable declaration -> C string
   (TypePrimitive("long"), "x") -> "long x;" *)
let ast_to_str_decl (var_type, name) =
  Printf.sprintf "%s %s;" (ast_to_str_type var_type) name
;;
  
(* AST for an expression -> C string *)
let rec ast_to_str_expr ast =
  match ast with
    ExprIntLiteral(x) ->
     (* ExprIntLiteral(123) -> "123" *)
     Int64.to_string x
  | ExprId(s) ->
     (* ExprId("x") -> "x" *)
     s
  | ExprOp(op, args) ->
     (* ExprOp("+" [ExprId("x"); ExprIntLiteral("123")]) -> "x + 123" *)
     String.concat (Printf.sprintf " %s " op) (List.map ast_to_str_expr args)
  | ExprCall(func, args) ->
     (* ExprCall(ExprId("f"), [ExprId("x"); ExprIntLiteral("123")]) -> "f(x, 123)" *)
     Printf.sprintf "%s(%s)"
       (ast_to_str_expr func)
       (String.concat ", " (List.map ast_to_str_expr args))
  | ExprParen(expr) ->
     (* ExprParen(ExprOp("+", [ExprId("x"); ExprIntLiteral("123")])) -> "(x + 123)" *)
     Printf.sprintf "(%s)" (ast_to_str_expr expr)
;;
  
(* AST for a statement -> C string *)
let rec ast_to_str_stmt ast =
  match ast with
    StmtEmpty ->
     ";"
  | StmtContinue ->
     "continue;"
  | StmtBreak ->
     "break;"
  | StmtReturn(expr) ->
     Printf.sprintf "return %s;" (ast_to_str_expr expr)
  | StmtExpr(expr) ->
     Printf.sprintf "%s;" (ast_to_str_expr expr)
  | StmtCompound(decls, stmts) ->
     Printf.sprintf "{\n%s\n%s\n}"
       (String.concat "\n" (List.map ast_to_str_decl decls))
       (String.concat "\n" (List.map ast_to_str_stmt stmts))
  | StmtIf(cond, then_stmt, Some(else_stmt)) ->
     Printf.sprintf "if (%s) %s else %s"
       (ast_to_str_expr cond)
       (ast_to_str_stmt then_stmt)
       (ast_to_str_stmt else_stmt)
  | StmtIf(cond, then_stmt, None) ->
     Printf.sprintf "if (%s) %s"
       (ast_to_str_expr cond)
       (ast_to_str_stmt then_stmt)
  | StmtWhile(cond, body) ->
     Printf.sprintf "while (%s) %s"
       (ast_to_str_expr cond)
       (ast_to_str_stmt body)
;;

(* AST for a definition -> C string *)
let ast_to_str_def ast =
  match ast with
    DefFun(name, params, return_type, stmt) ->
    (* DefFun("f", [(TypePrimitive("long"), "x")], TypePrimitive("long"), 
                    StmtCompound([], [])) ->
       long f(long x) {} *)
    Printf.sprintf "%s %s(%s) %s"
      (ast_to_str_type return_type) name
      (String.concat ", " (List.map ast_to_str_param params))
      (ast_to_str_stmt stmt)
;;    

let ast_to_str_program ast =
  match ast with
    Program(defs) ->
    String.concat "\n" (List.map ast_to_str_def defs)
;;

