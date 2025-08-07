package main

/* minc_parse

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

*/

import "fmt"
import "log"
import "os"
import "strconv"
import "github.com/subchen/go-xmldom"

/* --- things related to string -> dom --- */

/* string -> dom
   <foo>bar</foo> -> Element("foo", [Text("bar")]) */
func str_to_dom(s string) * xmldom.Node {
	var node * xmldom.Node = xmldom.Must(xmldom.ParseXML(s)).Root
	return node
}

/* xml in file -> dom */
func file_xml_to_dom(file_xml string) * xmldom.Node {
	contentb, err := os.ReadFile(file_xml)
	if err != nil {
		log.Fatal(err)
	}
	return str_to_dom(string(contentb))
}

/* --- parser (XML DOM -> Abstract Syntax Tree) ---

   dom_to_ast_xxxx converts a dom tree supposedly 
   representing xxxx into the corresponding abstract
   syntax tree (see minc_ast for its definition).

   e.g., dom_to_ast_expr converts a dom tree supposedly
   representing an expression into a data 
   representing an expression. 

*/

/* panic when the input XML DOM tree does not have the right structure */
func invalid_xml(elem * xmldom.Node) {
	panic(fmt.Sprintf("%s", elem.XML()))
}

// check if this is a node like <tag/>
func check_singleton(elem * xmldom.Node) {
	if len(elem.Children) != 0 { invalid_xml(elem) }
	if elem.Text != "" { invalid_xml(elem) }
}

// check if this is a node like <tag>text</tag> and returns text
func check_get_text(elem * xmldom.Node) string {
	if len(elem.Children) != 0 { invalid_xml(elem) }
	if elem.Text == "" { invalid_xml(elem) }
	return elem.Text
}

// check if this is a node like <tag>elem</tag> and return elem
func check_get_child_1(elem * xmldom.Node) * xmldom.Node {
	children := elem.Children
	if len(children) != 1 { invalid_xml(elem) }
	return children[0]
}

// check if this is a node like <tag><t0>c0</t0><t1>c1</t1></tag> and return c0, c1
func check_get_children_2(elem * xmldom.Node, t0 string, t1 string) (* xmldom.Node, * xmldom.Node) {
	children := elem.Children
	if len(children) != 2 { invalid_xml(elem) }
	if children[0].Name != t0 { invalid_xml(elem) }
	if children[1].Name != t1 { invalid_xml(elem) }
	return children[0], children[1]
}

// check if this is a node like <tag><t0>c0</t0><t1>c1</t1><t2>c2</t2></tag> and return c0, c1, c2
func check_get_children_3(elem * xmldom.Node, t0 string, t1 string, t2 string) (* xmldom.Node, * xmldom.Node, * xmldom.Node) {
	children := elem.Children
	if len(children) != 3 { invalid_xml(elem) }
	if children[0].Name != t0 { invalid_xml(elem) }
	if children[1].Name != t1 { invalid_xml(elem) }
	if children[2].Name != t2 { invalid_xml(elem) }
	return children[0], children[1], children[2]
}

// check if this is a node like <tag><t0>c0</t0><t1>c1</t1><t2>c2</t2></tag> and return c0, c1, c2
func check_get_children_4(elem * xmldom.Node, t0 string, t1 string, t2 string, t3 string) (* xmldom.Node, * xmldom.Node, * xmldom.Node, * xmldom.Node) {
	children := elem.Children
	if len(children) != 4 { invalid_xml(elem) }
	if children[0].Name != t0 { invalid_xml(elem) }
	if children[1].Name != t1 { invalid_xml(elem) }
	if children[2].Name != t2 { invalid_xml(elem) }
	if children[3].Name != t3 { invalid_xml(elem) }
	return children[0], children[1], children[2], children[3]
}

/* dom tree for type expression -> ast for type expression
   (note: only possible type expression in minc is "long".
   the framework is designed so it is easy to extend it with
   a new type) */
func dom_to_ast_type(elem * xmldom.Node) TypeExpr {
	// <primitive_type>long</primitive_type>
	switch elem.Name {
	case "primitive_type" :
		name := check_get_text(elem)
		return &TypePrimitive{name}
	}
	invalid_xml(elem)
	return nil
}

/* dom tree for expression -> ast for expression */
func dom_to_ast_expr(elem * xmldom.Node) Expr {
	switch elem.Name {
	case "int_literal" : {	// <int_literal>123</int_literal>
		s := check_get_text(elem)
		val, err := strconv.ParseInt(s, 10, 64)
		if err != nil { invalid_xml(elem) }
		return &ExprIntLiteral{val}
	}
	case "var" : {		// <var>x</var>
		name := check_get_text(elem)
		return &ExprId{name}
	}
	case "un_op" : {	// <un_op><op>-</op><arg>expr</arg></un_op>
		op_elem, arg_elem := check_get_children_2(elem, "op", "arg")
		op := check_get_text(op_elem)
		arg := dom_to_ast_expr(check_get_child_1(arg_elem))
		return &ExprOp{op, []Expr{arg}}
	}
	case "bin_op" : {	// <bin_op><op>+</op><left>expr</left><right>expr</right></bin_op>
		op_elem, left_elem, right_elem := check_get_children_3(elem, "op", "left", "right")
		op := check_get_text(op_elem)
		left := dom_to_ast_expr(check_get_child_1(left_elem))
		right := dom_to_ast_expr(check_get_child_1(right_elem))
		return &ExprOp{op, []Expr{left, right}}
	}
	case "call" : {		// <call><fun>expr</fun><args>expr expr expr ...</args></call>
		fun_elem, args_elem := check_get_children_2(elem, "fun", "args")
		fun := dom_to_ast_expr(check_get_child_1(fun_elem))
		args := map_array(dom_to_ast_expr, args_elem.Children)
		return &ExprCall{fun, args}
	}
	case "paren" : {	// <paren>expr</paren>
		expr := dom_to_ast_expr(check_get_child_1(elem))
		return &ExprParen{expr}
	}
	}
	invalid_xml(elem)
	return nil
}

/* dom tree for variable declaration -> ast for variable declaration */
func dom_to_ast_decl(elem * xmldom.Node) * Decl {
	// <decl><type>TYPE</type><name>X</name></decl>
	switch elem.Name {
	case "decl" :
		var_type_elem, var_name_elem := check_get_children_2(elem, "type", "name")
		var_type := dom_to_ast_type(check_get_child_1(var_type_elem))
		var_name := check_get_text(var_name_elem)
		return &Decl{var_type, var_name}
	}
	invalid_xml(elem)
	return nil
}

/* dom tree for statement -> ast for statement */
func dom_to_ast_stmt(elem * xmldom.Node) Stmt {
	switch elem.Name {
	case "empty" : {	// <empty></empty>
		check_singleton(elem)
		return &StmtEmpty{}
	}
	case "continue" : {	// <continue></continue>
		check_singleton(elem)
		return &StmtContinue{}
	}
	case "break" : {	// <break></break>
		check_singleton(elem)
		return &StmtBreak{}
	}
	case "return" : {	// <return>expr</return>
		return_expr := dom_to_ast_expr(check_get_child_1(elem))
		return &StmtReturn{return_expr}
	}
	case "expr_stmt" : {	// <expr_stmt>expr</expr_stmt>
		expr := dom_to_ast_expr(check_get_child_1(elem))
		return &StmtExpr{expr}
	}
	case "compound" : {	// <compound><decls>...</decls><stmts>...</stmts></compound>
		decls_elem, stmts_elem := check_get_children_2(elem, "decls", "stmts")
		decls := map_array(dom_to_ast_decl, decls_elem.Children)
		stmts := map_array(dom_to_ast_stmt, stmts_elem.Children)
		return &StmtCompound{decls, stmts}
	}
	case "if" : {		// <if><cond>expr</cond><then>stmt</then><else>stmt</else></if>
		children := elem.Children
		if len(children) == 3 {
			cond_elem, then_elem, else_elem := check_get_children_3(elem, "cond", "then", "else")
			cond := dom_to_ast_expr(check_get_child_1(cond_elem))
			then_stmt := dom_to_ast_stmt(check_get_child_1(then_elem))
			else_stmt := dom_to_ast_stmt(check_get_child_1(else_elem))
			return &StmtIf{cond, then_stmt, else_stmt}
		} else if len(children) == 2 {
			cond_elem, then_elem := check_get_children_2(elem, "cond", "then")
			cond := dom_to_ast_expr(check_get_child_1(cond_elem))
			then_stmt := dom_to_ast_stmt(check_get_child_1(then_elem))
			return &StmtIf{cond, then_stmt, nil}
		}
		invalid_xml(elem)
	}
	case "while" : {		// <while><cond>expr</cond><body>stmt</body></while>
		cond_elem, body_elem := check_get_children_2(elem, "cond", "body")
		cond := dom_to_ast_expr(check_get_child_1(cond_elem))
		body := dom_to_ast_stmt(check_get_child_1(body_elem))
		return &StmtWhile{cond, body}
	}
	}
	invalid_xml(elem)
	return nil
}

/* dom tree for a function parameter -> ast for parameter */
func dom_to_ast_param(elem * xmldom.Node) * Decl {
	// <param><type>type_expr</type><name>x</name></param>
	switch elem.Name {
	case "param" : {
		param_type_elem, param_name_elem := check_get_children_2(elem, "type", "name")
		param_type := dom_to_ast_type(check_get_child_1(param_type_elem))
		param_name := check_get_text(param_name_elem)
		return &Decl{param_type, param_name}
	}
	}
	invalid_xml(elem)
	return nil
}

/* dom tree for a toplevel definition -> ast for a toplevel definition
   (note: only possible toplevel definition in minc is a function definition) */
func dom_to_ast_def(elem * xmldom.Node) Def {
	switch elem.Name {
	case "fun_def" :
		/* <fun_def>
                    <name>F</name>
                    <params>PARM ...</params>
                    <return_type>TYPE</return_type>
                    <body>STMT</body>
                   </fun_def> */
		name_elem, params_elem, return_type_elem, body_elem := check_get_children_4(elem, "name", "params", "return_type", "body")
		name := check_get_text(name_elem)
		params := map_array(dom_to_ast_param, params_elem.Children)
		return_type := dom_to_ast_type(check_get_child_1(return_type_elem))
		body := dom_to_ast_stmt(check_get_child_1(body_elem))
		return &DefFun{name, params, return_type, body}
	}
	invalid_xml(elem)
	return nil
}

/* dom tree for a program -> ast for a program */
func dom_to_ast_program(elem * xmldom.Node) * Program {
	//* <program>DEF ...</program> 
	switch elem.Name {
	case "program" :
		defs := map_array(dom_to_ast_def, elem.Children)
		return &Program{defs}
	}
	invalid_xml(elem)
	return nil
}

/* XML string -> abstract syntax tree */
func str_to_ast(s string) * Program {
	dom := str_to_dom(s)
	if dom == nil { return nil }
	return dom_to_ast_program(dom)
}

/* XML file -> abstract syntax tree */
func file_xml_to_ast(file_xml string) * Program {
	contentb, err := os.ReadFile(file_xml)
	if err != nil {
		log.Fatal(err)
	}
	return str_to_ast(string(contentb))
}

