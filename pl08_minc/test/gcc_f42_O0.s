	.arch armv8-a
	.file	"f42.c"
	.text
	.align	2
	.global	sum2
	.type	sum2, %function
sum2:
.LFB0:
	.cfi_startproc
	sub	sp, sp, #32
	.cfi_def_cfa_offset 32
	str	x0, [sp, 8]
	str	xzr, [sp, 16]
	str	xzr, [sp, 24]
	b	.L2
.L3:
	ldr	x1, [sp, 24]
	ldr	x0, [sp, 16]
	add	x0, x1, x0
	str	x0, [sp, 24]
	ldr	x0, [sp, 16]
	add	x0, x0, 1
	str	x0, [sp, 16]
.L2:
	ldr	x0, [sp, 8]
	mul	x0, x0, x0
	ldr	x1, [sp, 16]
	cmp	x1, x0
	blt	.L3
	ldr	x0, [sp, 24]
	add	sp, sp, 32
	.cfi_def_cfa_offset 0
	ret
	.cfi_endproc
.LFE0:
	.size	sum2, .-sum2
	.align	2
	.global	f
	.type	f, %function
f:
.LFB1:
	.cfi_startproc
	stp	x29, x30, [sp, -32]!
	.cfi_def_cfa_offset 32
	.cfi_offset 29, -32
	.cfi_offset 30, -24
	mov	x29, sp
	str	x0, [sp, 24]
	ldr	x0, [sp, 24]
	mov	x1, 22859
	movk	x1, 0x3886, lsl 16
	movk	x1, 0xc5d6, lsl 32
	movk	x1, 0x346d, lsl 48
	smulh	x1, x0, x1
	asr	x2, x1, 11
	asr	x1, x0, 63
	sub	x1, x2, x1
	mov	x2, 10000
	mul	x1, x1, x2
	sub	x1, x0, x1
	mov	x0, x1
	bl	sum2
	ldp	x29, x30, [sp], 32
	.cfi_restore 30
	.cfi_restore 29
	.cfi_def_cfa_offset 0
	ret
	.cfi_endproc
.LFE1:
	.size	f, .-f
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
