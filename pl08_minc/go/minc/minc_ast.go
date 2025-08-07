package main
import "fmt"

/* Abstract Syntax Tree */

/* type expression:

   for now, we only have a primitive type (long),
   which is TypePrimitive{"long"} */

type TypeExpr interface {
	ast_to_str_type() string
}

type TypePrimitive struct {
	name string		// type name (always "long", for now)
}

/* variable declaration:

   long x; -> Decl{TypePrimitive("long"), "x"}
   also (ab)used to represent a function parameter */
type Decl struct {
	var_type TypeExpr	// variable type
	name string		// variable name
}

/* expression */
type Expr interface {
	ast_to_str_expr() string
}

/* 1, 2, 3, ... */
type ExprIntLiteral struct { val int64 }

/* x, y, z, ... */
type ExprId struct { name string }

/* -x, x - y, ... */
type ExprOp struct {
	op string
	args []Expr
}

/* f(1, 2, 3) */
type ExprCall struct {
	fun Expr
	args []Expr
}

/* (x + y) */
type ExprParen struct { sub_expr Expr }

/* statement */
type Stmt interface {
	ast_to_str_stmt() string
}

/* ; */
type StmtEmpty struct { }

/* continue; */
type StmtContinue struct { }

/* break; */
type StmtBreak struct { }

/* return e; */
type StmtReturn struct { expr Expr }

/* f(x); */
type StmtExpr struct { expr Expr }

/* { int x; return x + 1; } */
type StmtCompound struct {
	decls []*Decl
	stmts []Stmt
}

/* if (expr) stmt [else stmt] */
type StmtIf struct {
	cond Expr
	then_stmt Stmt
	else_stmt Stmt
}

/* while (expr) stmt */
type StmtWhile struct {
	cond Expr
	body Stmt
}

/* toplevel definition */
type Def interface {
	ast_to_str_def() string
}

/* function definition
     e.g., long f(long x, long y) { return x; }
*/
type DefFun struct {
	name string
	params []*Decl
	return_type TypeExpr
	body Stmt
}

/* program is just a list of definitions */
type Program struct {
	defs []Def
}


/* convert ast back to C string

   ast_to_str_xxx converts an AST to a string 
   valid as a C program.

   it will not be used anywhere in your compiler, 
   but is given for illustrating how you walk
   the AST and what kind of C program each AST 
   is actually meant to represent.
*/

// [f(a[0]), f(a[1]), ... ]
func map_array[S any, T any] (f func(S) T, a []S) []T {
	b := make([]T, len(a))
	for i, v := range a {
		b[i] = f(v)
	}
	return b
}

// a[0] sep a[1] sep ... sep a[n-1]
func concat(sep string, a []string) string {
	n := len(a)
	if n == 0 { return "" }
	if n == 1 { return a[0] }
	l := concat(sep, a[:n/2])
	r := concat(sep, a[n/2:])
	return fmt.Sprintf("%s%s%s", l, sep, r)
}

/* AST for type expression -> C string
   TypeExpr::Primitive{"long"} -> "long" */
func (type_expr * TypePrimitive) ast_to_str_type() string {
	return type_expr.name
}

/* AST for function parameter -> C string
   Decl{TypePrimitive("long"), "x"} -> "long x" */
func (param * Decl) ast_to_str_param() string {
	return fmt.Sprintf("%s %s", param.var_type.ast_to_str_type(), param.name)
}

/* AST for a variable declaration -> C string
   Decl{TypePrimitive("long"), "x"} -> "long x;" */
func (decl * Decl) ast_to_str_decl() string {
	return fmt.Sprintf("%s %s;", decl.var_type, decl.name)
}

/* AST for an expression -> C string */

/* ExprIntLiteral{123} -> "123" */
func (expr * ExprIntLiteral) ast_to_str_expr() string {
	return fmt.Sprintf("%d", expr.val)
}

/* ExprId("x") -> "x" */
func (expr * ExprId) ast_to_str_expr() string {
	return expr.name
}

/* ExprOp("+" [ExprId("x"); ExprIntLiteral("123")]) -> "x + 123" */
func (expr * ExprOp) ast_to_str_expr() string {
	return concat(fmt.Sprintf(" %s ", expr.op),
		map_array(func (e Expr) string { return e.ast_to_str_expr() }, expr.args))
}

/* ExprCall(ExprId("f"), [ExprId("x"); ExprIntLiteral("123")]) -> "f(x, 123)" */
func (expr * ExprCall) ast_to_str_expr() string {
	fun := expr.fun.ast_to_str_expr()
	args := concat(", ", map_array(func (e Expr) string { return e.ast_to_str_expr() }, expr.args))
	return fmt.Sprintf("%s(%s)", fun, args)
}

/* ExprParen(ExprOp("+", [ExprId("x"); ExprIntLiteral("123")])) -> "(x + 123)" */
func (expr * ExprParen) ast_to_str_expr() string {
	sub_expr := expr.sub_expr.ast_to_str_expr()
	return fmt.Sprintf("(%s)", sub_expr)
}

/* AST for a statement -> C string */

func (stmt * StmtEmpty) ast_to_str_stmt() string {
	return ";"
}

func (stmt * StmtContinue) ast_to_str_stmt() string {
	return "continue;"
}

func (stmt * StmtBreak) ast_to_str_stmt() string {
	return "break;"
}

func (stmt * StmtReturn) ast_to_str_stmt() string {
	return fmt.Sprintf("return %s;", stmt.expr.ast_to_str_expr())
}

func (stmt * StmtExpr) ast_to_str_stmt() string {
	return fmt.Sprintf("%s;", stmt.expr.ast_to_str_expr())
}

func (stmt * StmtCompound) ast_to_str_stmt() string {
	decls := concat("\n", map_array(func (d * Decl) string { return d.ast_to_str_decl() }, stmt.decls))
	stmts := concat("\n", map_array(func (s Stmt) string { return s.ast_to_str_stmt() }, stmt.stmts))
	return fmt.Sprintf("{\n%s\n%s\n}", decls, stmts)
}

func (stmt * StmtIf) ast_to_str_stmt() string {
	cond := stmt.cond.ast_to_str_expr()
	then_stmt := stmt.then_stmt.ast_to_str_stmt()
	if stmt.else_stmt == nil {
		return fmt.Sprintf("if (%s) %s", cond, then_stmt)
	} else {
		else_stmt := stmt.else_stmt.ast_to_str_stmt()
		return fmt.Sprintf("if (%s) %s else %s", cond, then_stmt, else_stmt)
	}
}

func (stmt * StmtWhile) ast_to_str_stmt() string {
	cond := stmt.cond.ast_to_str_expr()
	body := stmt.body.ast_to_str_stmt()
	return fmt.Sprintf("while (%s) %s", cond, body)
}

/* AST for a definition -> C string


   DefFun{"f", [Decl(TypePrimitive("long"), "x")], TypePrimitive("long"), 
                    StmtCompound([], [])} ->
       "long f(long x) {}"
*/

func (def * DefFun) ast_to_str_def() string {
	name := def.name
	params := concat(", ", map_array(func (p * Decl) string { return p.ast_to_str_param() }, def.params))
	return_type := def.return_type.ast_to_str_type()
	body := def.body.ast_to_str_stmt()
	return fmt.Sprintf("%s %s(%s) %s", return_type, name, params, body)
}

func (prog * Program) ast_to_str_program() string {
	return concat("\n", map_array(func (def Def) string { return def.ast_to_str_def() }, prog.defs))
}

