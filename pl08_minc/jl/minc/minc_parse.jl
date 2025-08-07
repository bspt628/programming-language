#= minc_parse

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

=#

using LightXML

# --- things related to string -> dom ---

#= string -> dom
   <foo>bar</foo> -> Element("foo", [Text("bar")]) 
=#
function str_to_dom(s :: String)
    root(parse_string(s))
end

# xml in file -> dom
function file_xml_to_dom(file_xml :: String)
    xml_str = read(file_xml, String)
    str_to_dom(xml_str)
end

#= --- parser (XML DOM -> Abstract Syntax Tree) ---

   dom_to_ast_xxxx converts a dom tree supposedly 
   representing xxxx into the corresponding abstract
   syntax tree (see minc_ast for its definition).

   e.g., dom_to_ast_expr converts a dom tree supposedly
   representing an expression into a data 
   representing an expression. 

=#

struct InvalidXML <: Exception
    elem :: String
end

# raised when the input XML DOM tree does not have the right structure 
function invalid_xml(elem :: XMLElement)
    throw(InvalidXML(string(elem)))
end

# check if this is a node like <tag/>
function check_singleton(elem :: XMLElement)
    children = collect(child_elements(elem))
    length(children) == 0 || invalid_xml(elem)
    contents(elem) == "" || invalid_xml(elem)
end

# check if this is a node like <tag>text</tag> and returns text
function check_get_text(elem :: XMLElement)
    children = collect(child_elements(elem))
    length(children) == 0 || invalid_xml(elem)
    content(elem) != "" || invalid_xml(elem)
    content(elem)
end

# check if this is a node like <tag>elem</tag> and return elem
function check_get_child_1(elem :: XMLElement)
    children = collect(child_elements(elem))
    length(children) == 1 || invalid_xml(elem)
    children[1]
end

# check if this is a node like <tag><t0>c0</t0><t1>c1</t1></tag> and return c0, c1
function check_get_children_2(elem :: XMLElement, t1 :: String, t2 :: String)
    children = collect(child_elements(elem))
    length(children) == 2 || invalid_xml(elem)
    name(children[1]) == t1 || invalid_xml(elem)
    name(children[2]) == t2 || invalid_xml(elem)
    (children[1], children[2])
end

# check if this is a node like <tag><t0>c0</t0><t1>c1</t1><t2>c2</t2></tag> and return c0, c1, c2
function check_get_children_3(elem :: XMLElement,
                              t1 :: String, t2 :: String, t3 :: String)
    children = collect(child_elements(elem))
    length(children) == 3 || invalid_xml(elem)
    name(children[1]) == t1 || invalid_xml(elem)
    name(children[2]) == t2 || invalid_xml(elem)
    name(children[3]) == t3 || invalid_xml(elem)
    (children[1], children[2], children[3])
end

# check if this is a node like <tag><t0>c0</t0><t1>c1</t1><t2>c2</t2></tag> and return c0, c1, c2
function check_get_children_4(elem :: XMLElement,
                              t1 :: String, t2 :: String, t3 :: String, t4 :: String)
    children = collect(child_elements(elem))
    length(children) == 4 || invalid_xml(elem)
    name(children[1]) == t1 || invalid_xml(elem)
    name(children[2]) == t2 || invalid_xml(elem)
    name(children[3]) == t3 || invalid_xml(elem)
    name(children[4]) == t4 || invalid_xml(elem)
    (children[1], children[2], children[3], children[4])
end

#= dom tree for type expression -> ast for type expression
   (note: only possible type expression in minc is "long".
   the framework is designed so it is easy to extend it with
   a new type) 
=#
function dom_to_ast_type(elem :: XMLElement)
    # <primitive_type>long</primitive_type>
    tag = name(elem)
    if tag == "primitive_type"
	tname = check_get_text(elem)
	TypePrimitive(tname)
    else
	invalid_xml(elem)
    end
end

# dom tree for expression -> ast for expression 
function dom_to_ast_expr(elem :: XMLElement)
    tag = name(elem)
    if tag == "int_literal"
        # <int_literal>123</int_literal>
	s = check_get_text(elem)
	val = parse(Int64, s)
	ExprIntLiteral(val)
    elseif tag == "var"
        # <var>x</var>
	vname = check_get_text(elem)
	ExprId(vname)
    elseif tag == "un_op"
        # <un_op><op>-</op><arg>expr</arg></un_op>
	op_elem, arg_elem = check_get_children_2(elem, "op", "arg")
	op = check_get_text(op_elem)
	arg = dom_to_ast_expr(check_get_child_1(arg_elem))
	ExprOp(op, [arg])
    elseif tag == "bin_op"
        # <bin_op><op>+</op><left>expr</left><right>expr</right></bin_op>
	op_elem, left_elem, right_elem = check_get_children_3(elem, "op", "left", "right")
	op = check_get_text(op_elem)
	left = dom_to_ast_expr(check_get_child_1(left_elem))
	right = dom_to_ast_expr(check_get_child_1(right_elem))
	ExprOp(op, [left, right])
    elseif tag == "call"
        # <call><fun>expr</fun><args>expr expr expr ...</args></call>
	fun_elem, args_elem = check_get_children_2(elem, "fun", "args")
	fun = dom_to_ast_expr(check_get_child_1(fun_elem))
	args = map(dom_to_ast_expr, child_elements(args_elem))
	ExprCall(fun, args)
    elseif tag == "paren"
        # <paren>expr</paren>
	expr = dom_to_ast_expr(check_get_child_1(elem))
	ExprParen(expr)
    else
	invalid_xml(elem)
    end
end

# dom tree for variable declaration -> ast for variable declaration
function dom_to_ast_decl(elem :: XMLElement)
    # <decl><type>type_expr</type><name>x</name></decl>
    tag = name(elem)
    if tag == "decl"
	var_type_elem, var_name_elem = check_get_children_2(elem, "type", "name")
	var_type = dom_to_ast_type(check_get_child_1(var_type_elem))
	var_name = check_get_text(var_name_elem)
	Decl(var_type, var_name)
    else
	invalid_xml(elem)
    end
end

# dom tree for statement -> ast for statement
function dom_to_ast_stmt(elem :: XMLElement)
    tag = name(elem)
    if tag == "empty"
        # <empty></empty>
	check_singleton(elem)
	StmtEmpty()
    elseif tag == "continue"
        # <continue></continue>
	check_singleton(elem)
	StmtContinue()
    elseif tag == "break"
        # <break></break>
	check_singleton(elem)
	StmtBreak()
    elseif tag == "return"
        # <return>expr</return>
	return_expr = dom_to_ast_expr(check_get_child_1(elem))
	StmtReturn(return_expr)
    elseif tag == "expr_stmt"
        # <expr_stmt>expr</expr_stmt>
	expr = dom_to_ast_expr(check_get_child_1(elem))
	StmtExpr(expr)
    elseif tag == "compound"
        # <compound><decls>...</decls><stmts>...</stmts></compound>
	decls_elem, stmts_elem = check_get_children_2(elem, "decls", "stmts")
	decls = map(dom_to_ast_decl, child_elements(decls_elem))
	stmts = map(dom_to_ast_stmt, child_elements(stmts_elem))
	StmtCompound(decls, stmts)
    elseif tag == "if"
        # <if><cond>expr</cond><then>stmt</then><else>stmt</else></if>
	children = collect(child_elements(elem))
	if length(children) == 3
	    cond_elem, then_elem, else_elem = check_get_children_3(elem, "cond", "then", "else")
	    cond = dom_to_ast_expr(check_get_child_1(cond_elem))
	    then_stmt = dom_to_ast_stmt(check_get_child_1(then_elem))
	    else_stmt = dom_to_ast_stmt(check_get_child_1(else_elem))
	    StmtIf(cond, then_stmt, else_stmt)
	elseif length(children) == 2
	    cond_elem, then_elem = check_get_children_2(elem, "cond", "then")
	    cond = dom_to_ast_expr(check_get_child_1(cond_elem))
	    then_stmt = dom_to_ast_stmt(check_get_child_1(then_elem))
	    StmtIf(cond, then_stmt, nothing)
        else
	    invalid_xml(elem)
        end
    elseif tag == "while"
        # <while><cond>expr</cond><body>stmt</body></while>
	cond_elem, body_elem = check_get_children_2(elem, "cond", "body")
	cond = dom_to_ast_expr(check_get_child_1(cond_elem))
	body = dom_to_ast_stmt(check_get_child_1(body_elem))
	StmtWhile(cond, body)
    else
	invalid_xml(elem)
    end
end

# dom tree for a function parameter -> ast for parameter
function dom_to_ast_param(elem :: XMLElement)
    # <param><type>type_expr</type><name>x</name></param>
    tag = name(elem)
    if tag == "param"
	param_type_elem, param_name_elem = check_get_children_2(elem, "type", "name")
	param_type = dom_to_ast_type(check_get_child_1(param_type_elem))
	param_name = check_get_text(param_name_elem)
	Decl(param_type, param_name)
    else
	invalid_xml(elem)
    end
end

#= dom tree for a toplevel definition -> ast for a toplevel definition
   (note: only possible toplevel definition in minc is a function definition)
=#
function dom_to_ast_def(elem :: XMLElement)
    tag = name(elem)
    if tag == "fun_def"
	# <fun_def>
	#  <name>f</name>
	#  <params>
	#   <param><type>TYPE</type><name>x</name></param>
	#   <param><type>TYPE</type><name>y</name></param>
	#  </params>
	#  <return_type>TYPE</return_type>
	#  <body>STMT</body>
	# </fun_def>
	name_elem, params_elem, return_type_elem, body_elem = check_get_children_4(elem, "name", "params", "return_type", "body")
	fname = check_get_text(name_elem)
	params = map(dom_to_ast_param, child_elements(params_elem))
	return_type = dom_to_ast_type(check_get_child_1(return_type_elem))
	body = dom_to_ast_stmt(check_get_child_1(body_elem))
	DefFun(fname, params, return_type, body)
    else
	invalid_xml(elem)
    end
end

# dom tree for a program -> ast for a program
function dom_to_ast_program(elem :: XMLElement)
    tag = name(elem)
    if tag == "program"
	defs = map(dom_to_ast_def, child_elements(elem))
	Program(defs)
    else
	invalid_xml(elem)
    end
end

# XML string -> abstract syntax tree
function str_to_ast(s :: String)
    dom = str_to_dom(s)
    if dom == nothing
        return nothing
    end
    dom_to_ast_program(dom)
end

# XML file -> abstract syntax tree
function file_xml_to_ast(file_xml :: String)
    xml_str = read(file_xml, String)
    str_to_ast(xml_str)
end

