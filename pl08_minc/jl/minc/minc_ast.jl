import Printf

#= 
Abstract Syntax Tree 
=#

#= type expression:

   for now, we only have a primitive type (long),
   which is TypePrimitive("long")
=#

abstract type TypeExpr end

struct TypePrimitive <: TypeExpr
    name :: String              # type name (always "long", for now)
end

#= variable declaration:

   long x; -> Decl(TypePrimitive("long"), "x")
   also (ab)used to represent a function parameter
=#
struct Decl
    var_type :: TypeExpr        # variable type
    name :: String              # variable name
end

# expression
abstract type Expr end

# 1, 2, 3, ... 
struct ExprIntLiteral <: Expr
    val :: Int64
end

# x, y, z, ...
struct ExprId <: Expr
    name :: String
end

# -x, x - y, ...
struct ExprOp <: Expr
    op :: String
    args :: Vector{Expr}
end

# f(1, 2, 3)
struct ExprCall <: Expr
    fun :: Expr
    args :: Vector{Expr}
end

# (x + y)
struct ExprParen <: Expr
    sub_expr :: Expr
end

#= 
statement
=#
abstract type Stmt end

# ;
struct StmtEmpty <: Stmt end

# continue;
struct StmtContinue <: Stmt end

# break;
struct StmtBreak <: Stmt end

# return e;
struct StmtReturn <: Stmt
    expr :: Expr
end

# f(x);
struct StmtExpr <: Stmt
    expr :: Expr
end

# { int x; return x + 1; } 
struct StmtCompound <: Stmt
    decls :: Vector{Decl}
    stmts :: Vector{Stmt}
end    

# if (expr) stmt [else stmt]
struct StmtIf <: Stmt
    cond :: Expr
    then_stmt :: Stmt
    else_stmt :: Union{Stmt,Nothing}
end

# while (expr) stmt
struct StmtWhile <: Stmt
    cond :: Expr
    body :: Stmt
end

#= 
toplevel definition
=#
abstract type Def end

#= 
function definition
e.g., long f(long x, long y) { return x; }
=#
struct DefFun <: Def
    name :: String
    params :: Vector{Decl}
    return_type :: TypeExpr
    body :: Stmt
end

# program is just a list of definitions
struct Program
    defs :: Vector{Def}
end

#=
convert ast back to C string

ast_to_str_xxx converts an AST to a string 
valid as a C program.

it will not be used anywhere in your compiler, 
but is given for illustrating how you walk
the AST and what kind of C program each AST 
is actually meant to represent.
=#

#=
 AST for type expression -> C string
TypeExpr::Primitive{"long"} -> "long"
=#
function ast_to_str_type(type_expr :: TypePrimitive)
    type_expr.name
end

#= 
AST for function parameter -> C string
Decl{TypePrimitive("long"), "x"} -> "long x"
=#
function ast_to_str_param(param :: Decl)
    Printf.@sprintf("%s %s", ast_to_str_type(param.var_type), param.name)
end

#=
 AST for a variable declaration -> C string
Decl{TypePrimitive("long"), "x"} -> "long x;"
=#
function ast_to_str_decl(decl :: Decl)
    Printf.@sprintf("%s %s;", decl.var_type, decl.name)
end

#= 
AST for an expression -> C string
=#

# ExprIntLiteral{123} -> "123"
function ast_to_str_expr(expr :: ExprIntLiteral)
    Printf.@sprintf("%d", expr.val)
end

# ExprId("x") -> "x"
function ast_to_str_expr(expr :: ExprId)
    expr.name
end

# ExprOp("+" [ExprId("x"); ExprIntLiteral("123")]) -> "x + 123"
function ast_to_str_expr(expr :: ExprOp)
    return join(map(ast_to_str_expr, expr.args), 
                Printf.@sprintf(" %s ", expr.op))
end

# ExprCall(ExprId("f"), [ExprId("x"); ExprIntLiteral("123")]) -> "f(x, 123)"
function ast_to_str_expr(expr :: ExprCall)
    fun = ast_to_str_expr(expr.fun)
    args = join(map(ast_to_str_expr, expr.args), ", ")
    Printf.@sprintf("%s(%s)", fun, args)
end

# ExprParen(ExprOp("+", [ExprId("x"); ExprIntLiteral("123")])) -> "(x + 123)"
function ast_to_str_expr(expr :: ExprParen)
    sub_expr = ast_to_str_expr(expr.sub_expr)
    Printf.@sprintf("(%s)", sub_expr)
end

#=
AST for a statement -> C string
=#

function ast_to_str_stmt(stmt :: StmtEmpty)
    ";"
end

function ast_to_str_stmt(stmt :: StmtContinue)
    "continue;"
end

function ast_to_str_stmt(stmt :: StmtBreak)
    "break;"
end

function ast_to_str_stmt(stmt :: StmtReturn)
    Printf.@sprintf("return %s;", ast_to_str_expr(stmt.expr))
end

function ast_to_str_stmt(stmt :: StmtExpr)
    Printf.@sprintf("%s;", ast_to_str_expr(stmt.expr))
end

function ast_to_str_stmt(stmt :: StmtCompound)
    decls = join(map(ast_to_str_decl, stmt.decls), "\n")
    stmts = join(map(ast_to_str_stmt, stmt.stmts), "\n")
    Printf.@sprintf("{\n%s\n%s\n}", decls, stmts)
end

function ast_to_str_stmt(stmt :: StmtIf)
    cond = ast_to_str_expr(stmt.cond)
    then_stmt = ast_to_str_stmt(stmt.then_stmt)
    if stmt.else_stmt == nothing
	Printf.@sprintf("if (%s) %s", cond, then_stmt)
    else
	else_stmt = ast_to_str_stmt(stmt.else_stmt)
	Printf.@sprintf("if (%s) %s else %s", cond, then_stmt, else_stmt)
    end
end

function ast_to_str_stmt(stmt :: StmtWhile)
    cond = ast_to_str_expr(stmt.cond)
    body = ast_to_str_stmt(stmt.body)
    Printf.@sprintf("while (%s) %s", cond, body)
end

#=
 AST for a definition -> C string


   DefFun("f", [Decl(TypePrimitive("long"), "x")], TypePrimitive("long"), 
                    StmtCompound([], [])) ->
       "long f(long x) {}"
=#
function ast_to_str_def(def :: DefFun)
    fname = def.name
    params = join(map(ast_to_str_param, def.params), ", ")
    return_type = ast_to_str_type(def.return_type)
    body = ast_to_str_stmt(def.body)
    Printf.@sprintf("%s %s(%s) %s", return_type, fname, params, body)
end

function ast_to_str_program(prog :: Program)
    join(map(ast_to_str_def, prog.defs), "\n")
end

