	.arch armv8-a
	.file	"f42.c"
	.text
	.align	2
	.p2align 4,,11
	.global	sum2
	.type	sum2, %function
sum2:
.LFB0:
	.cfi_startproc
	mul	x2, x0, x0
	mov	x0, 0
	cbz	x2, .L1
	mov	x1, 0
	.p2align 3,,7
.L3:
	add	x0, x0, x1
	add	x1, x1, 1
	cmp	x1, x2
	bne	.L3
.L1:
	ret
	.cfi_endproc
.LFE0:
	.size	sum2, .-sum2
	.align	2
	.p2align 4,,11
	.global	f
	.type	f, %function
f:
.LFB1:
	.cfi_startproc
	mov	x1, 22859
	mov	x3, 10000
	movk	x1, 0x3886, lsl 16
	movk	x1, 0xc5d6, lsl 32
	movk	x1, 0x346d, lsl 48
	smulh	x2, x0, x1
	asr	x2, x2, 11
	sub	x2, x2, x0, asr 63
	msub	x2, x2, x3, x0
	mov	x0, 0
	mul	x2, x2, x2
	cbz	x2, .L7
	mov	x1, 0
	.p2align 3,,7
.L9:
	add	x0, x0, x1
	add	x1, x1, 1
	cmp	x1, x2
	bne	.L9
.L7:
	ret
	.cfi_endproc
.LFE1:
	.size	f, .-f
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
