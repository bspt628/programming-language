#!/usr/bin/env julia
include("minc_ast.jl")
include("minc_parse.jl")
include("minc_cogen.jl")

# read XML file and convert it to assembly string
function file_xml_to_asm(file_xml :: String)
    program = file_xml_to_ast(file_xml)
    asm = ast_to_asm_program(program)
    asm
end

#= read XML file, convert it to assembly string, and write
   it to a file (file_asm)
=#
function file_xml_to_file_asm(file_xml :: String, file_asm :: String)
    asm = file_xml_to_asm(file_xml)
    open(file_asm, "w" ) do fp
        write(fp, asm)
    end
end

#= entry point 
   ./minc.jl fun.xml fun.s
   read an XML file and generate assembly code in fun.s
=#
function main()
    file_xml = ARGS[1]
    file_asm = ARGS[2]
    file_xml_to_file_asm(file_xml, file_asm)
end

main()

