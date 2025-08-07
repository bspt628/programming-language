	.arch armv8-a
	.file	"f17.c"
	.text
	.align	2
	.global	f
	.type	f, %function
f:
.LFB0:
	.cfi_startproc
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, 24]
	str	x1, [sp, 16]
	str	x2, [sp, 8]
	ldr	x1, [sp, 24]
	ldr	x0, [sp, 16]
	add	x1, x1, x0
	ldr	x0, [sp, 8]
	add	x0, x1, x0
	add	sp, sp, 32
	.cfi_def_cfa_offset 0
	ret
	.cfi_endproc
.LFE0:
	.size	f, .-f
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
