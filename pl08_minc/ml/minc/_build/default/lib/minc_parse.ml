(* minc_parse.ml

   parsing actually means converting XML into the
   Abstract Syntax Tree (AST) defined in the respective
   language (see minc_ast.{ml,jl,go,rs}).
   XML is made by converting the original source (.c) file
   by parser/minc_to_xml.py.

            minc_to_xml.py
   .c file ----------------> xml file

            str_to_dom (minc_parse)
           --------------------------> xml (DOM) tree

            dom_to_ast_{type,expr,stmt,...}
            (minc_parse)
           ---------------------------------> AST

   str_to_dom : convert a string into an XML tree (called
   Document Object Model, or DOM), using an appropriate
   XML parsing library of your language.

   dom_to_ast_{type,expr,stmt,...} : convert an XML tree representing 
   type, expression, statement, etc. into the respective AST.

   str_to_ast : convert a string representing a program
   into AST, by first calling str_to_dom and then dom_to_ast_program

   file_xml_to_ast : read an XML file (get a string) and 
   convert it into AST. this is the function called from the main
   function

 *)

open Minc_ast
;;

(* --- things related to string -> dom --- *)

(* data structure representing XML DOM tree
   <foo>bar</foo> => Element("foo", [Text("bar")])
 *)
type dom = Text of string       (* text node *)
         | Element of string * dom list (* element node *)
;;

(* true if it is either an element node or
   a text node with at least one non-whitespace chars *)
let not_whitespace_only_text x =
  match x with
    Text(s) -> String.trim(s) <> ""
  | Element(_, _) -> true
;;

(* get rid of whitespace-only text nodes *)
let rec remove_whitespace_only_texts dom =
  match dom with
    Text(s) -> Text(s)
  | Element(name, children) ->
     Element(name, List.map remove_whitespace_only_texts
                     (List.filter not_whitespace_only_text children))
;;

(* same as above, but gracefully handle None *)
let remove_whitespace_only_texts_opt dom_opt =
  match dom_opt with
    None -> None
  | Some(dom) -> Some(remove_whitespace_only_texts dom)
;;

(* string -> dom
   <foo>bar</foo> -> Element("foo", [Text("bar")]) *)
let str_to_dom s =
  s
  |> Markup.string
  |> Markup.parse_xml
  |> Markup.signals
  |> Markup.tree
       ~text:(fun ss -> Text (String.concat "" ss))
       ~element:(fun (_, name) _ children -> Element (name, children))
  |> remove_whitespace_only_texts_opt
;;

(* xml in file -> dom *)
let file_xml_to_dom file_xml =
  let ic = open_in file_xml in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  str_to_dom s
;;

(* --- parser (XML DOM -> Abstract Syntax Tree) --- 

   dom_to_ast_xxxx converts a dom tree supposedly 
   representing xxxx into the corresponding abstract
   syntax tree (see minc_ast for its definition).

   e.g., dom_to_ast_expr converts a dom tree supposedly
   representing an expression into a data 
   representing an expression. 
 *)

(* raised when the input XML DOM tree does not have the right structure *)
exception InvalidXML of dom
;;

(* dom tree for type expression -> ast for type expression
   (note: only possible type expression in minc is "long".
   the framework is designed so it is easy to extend it with
   a new type) *)

let dom_to_ast_type elem =
  match elem with
  | Element("primitive_type", [Text(name)]) ->
     (* <primitive_type>long</primitive_type> *)
     TypePrimitive(name)
  | _ -> raise (InvalidXML(elem))
;;

(* dom tree for expression -> ast for expression *)
let rec dom_to_ast_expr elem =
  match elem with
    Element("int_literal", [Text(s)]) ->
     (* <int_literal>123</int_literal> *)
     ExprIntLiteral(Int64.of_string s)
  | Element("var", [Text(s)]) ->
     (* <var>X</var> *)
     ExprId(s)
  | Element("un_op", [Element("op", [Text(op)]);
                      Element("arg", [arg])]) ->
     (* <un_op><op>-</op><arg>EXPR</arg></un_op> *)
     ExprOp(op, [dom_to_ast_expr arg])
  | Element("bin_op", [Element("op", [Text(op)]);
                       Element("left", [left]);
                       Element("right", [right])]) ->
     (* <bin_op><op>-</op><left>EXPR</left><right>EXPR</right></bin_op> *)
     ExprOp(op, [dom_to_ast_expr left; dom_to_ast_expr right])
  | Element("call", [Element("fun", [func]);
                     Element("args", args)]) ->
     (* <call><fun>EXPR</fun><args>EXPR ... </args></call> *)
     ExprCall(dom_to_ast_expr func, List.map dom_to_ast_expr args)
  | Element("paren", [sub_expr]) ->
     (* <paren>EXPR</paren> *)
     ExprParen(dom_to_ast_expr sub_expr)
  | _ -> raise (InvalidXML(elem))
;;

(* dom tree for variable declaration -> ast for variable declaration *)
let dom_to_ast_decl elem =
  match elem with
  | Element("decl", [Element("type", [type_expr]);
                     Element("name", [Text(s)])]) ->
     (* <decl><type>TYPE</type><name>X</name></decl> *)
     (dom_to_ast_type type_expr, s)
  | _ -> raise (InvalidXML(elem))
;;            

(* dom tree for statement -> ast for statement *)
let rec dom_to_ast_stmt elem =
  match elem with
  | Element("empty", []) -> StmtEmpty       (* <empty/> *)
  | Element("continue", []) -> StmtContinue (* <continue/> *)
  | Element("break", []) -> StmtBreak       (* <break/> *)
  | Element("return", [expr]) ->
     (* <return>EXPR</return> *)
     StmtReturn(dom_to_ast_expr expr)
  | Element("compound", [Element("decls", decls);
                         Element("stmts", stmts)]) ->
     (* <compound><decls>DECL ...</decls><stmts>STMT ...</stmts></compound> *)
     StmtCompound(List.map dom_to_ast_decl decls, 
                   List.map dom_to_ast_stmt stmts)
  | Element("if", [Element("cond", [cond]);
                   Element("then", [then_stmt]);
                   Element("else", [else_stmt])]) ->
     (* <if><cond>EXPR</cond><then>STMT</then><else>STMT</else></if> *)
     StmtIf(dom_to_ast_expr cond,
            dom_to_ast_stmt then_stmt,
            Some(dom_to_ast_stmt else_stmt))
  | Element("if", [Element("cond", [cond]);
                   Element("then", [then_stmt])]) ->
     (* <if><cond>EXPR</cond><then>STMT</then></if> *)
     StmtIf(dom_to_ast_expr cond,
            dom_to_ast_stmt then_stmt,
            None)
  | Element("while", [Element("cond", [cond]);
                      Element("body", [body])]) ->
     (* <while><cond>EXPR</cond><body>STMT</body></while> *)
     StmtWhile(dom_to_ast_expr cond, dom_to_ast_stmt body)
  | Element("expr_stmt", [expr]) ->
     (* <expr_stmt>EXPR</expr_stmt> *)
     StmtExpr(dom_to_ast_expr expr)
  | _ -> raise (InvalidXML(elem))
;;

(* dom tree for a function parameter -> ast for parameter *)
let dom_to_ast_param elem =
  match elem with
  | Element("param", [Element("type", [type_expr]);
                      Element("name", [Text(s)])]) ->
     (* <param><type>TYPE</type><name>X</name></param> *)
     (dom_to_ast_type type_expr, s)
  | _ -> raise (InvalidXML(elem))
;;

(* dom tree for a toplevel definition -> ast for a toplevel definition
   (note: only possible toplevel definition in minc is a function definition) *)
let dom_to_ast_def elem =
  match elem with
  | Element("fun_def", [Element("name", [Text(name)]);
                        Element("params", params);
                        Element("return_type", [return_type]);
                        Element("body", [body])]) ->
     (* <fun_def>
          <name>F</name>
          <params>PARM ...</params>
          <return_type>TYPE</return_type>
          <body>STMT</body>
        </fun_def> *)
     DefFun(name,
            List.map dom_to_ast_param params,
            dom_to_ast_type return_type,
            dom_to_ast_stmt body)
  | _ -> raise (InvalidXML(elem))
;;
  
(* dom tree for a program -> ast for a program *)
let dom_to_ast_program elem =
  match elem with
    Element("program", children) ->
     (* <program>DEF ...</program> *)
     Program(List.map dom_to_ast_def children)
  | _ -> raise (InvalidXML(elem))
;;

exception InvalidXMLString of string
;;

(* XML string -> abstract syntax tree *)
let str_to_ast s =
  match str_to_dom s with
    Some(dom) -> dom_to_ast_program dom 
  | None -> raise (InvalidXMLString(s))
;;

(* XML file -> abstract syntax tree *)
let file_xml_to_ast file_xml =
  let ic = open_in file_xml in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  str_to_ast s
;;

