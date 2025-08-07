	.arch armv8-a
	.file	"f00.c"
	.text
	.align	2
	.global	f
	.type	f, %function
f:
.LFB0:
	.cfi_startproc
	mov	x0, 123
	ret
	.cfi_endproc
.LFE0:
	.size	f, .-f
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
