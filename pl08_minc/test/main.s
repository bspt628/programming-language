	.arch armv8-a
	.file	"main.c"
	.text
	.section	.rodata
	.align	3
.LC0:
	.string	"%ld\n"
	.text
	.align	2
	.global	main
	.type	main, %function
main:
.LFB6:
	.cfi_startproc
	sub	sp, sp, #208
	.cfi_def_cfa_offset 208
	stp	x29, x30, [sp, 192]
	.cfi_offset 29, -16
	.cfi_offset 30, -8
	add	x29, sp, 192
	str	w0, [sp, 44]
	str	x1, [sp, 32]
	adrp	x0, :got:__stack_chk_guard
	ldr	x0, [x0, :got_lo12:__stack_chk_guard]
	ldr	x1, [x0]
	str	x1, [sp, 184]
	mov	x1, 0
	ldr	w0, [sp, 44]
	cmp	w0, 1
	ble	.L2
	ldr	x0, [sp, 32]
	add	x0, x0, 8
	ldr	x0, [x0]
	bl	atol
	b	.L3
.L2:
	mov	x0, 12345
.L3:
	str	x0, [sp, 64]
	ldr	x0, [sp, 64]
	and	w0, w0, 65535
	strh	w0, [sp, 80]
	ldr	x0, [sp, 64]
	asr	x0, x0, 16
	and	w0, w0, 65535
	strh	w0, [sp, 82]
	ldr	x0, [sp, 64]
	asr	x0, x0, 32
	and	w0, w0, 65535
	strh	w0, [sp, 84]
	str	xzr, [sp, 56]
	b	.L4
.L5:
	add	x0, sp, 80
	bl	nrand48
	mov	x2, x0
	ldr	x0, [sp, 56]
	lsl	x0, x0, 3
	add	x1, sp, 88
	str	x2, [x1, x0]
	ldr	x0, [sp, 56]
	add	x0, x0, 1
	str	x0, [sp, 56]
.L4:
	ldr	x0, [sp, 56]
	cmp	x0, 11
	ble	.L5
	ldr	x8, [sp, 88]
	ldr	x9, [sp, 96]
	ldr	x10, [sp, 104]
	ldr	x11, [sp, 112]
	ldr	x4, [sp, 120]
	ldr	x5, [sp, 128]
	ldr	x6, [sp, 136]
	ldr	x7, [sp, 144]
	ldr	x0, [sp, 152]
	ldr	x1, [sp, 160]
	ldr	x2, [sp, 168]
	ldr	x3, [sp, 176]
	str	x3, [sp, 24]
	str	x2, [sp, 16]
	str	x1, [sp, 8]
	str	x0, [sp]
	mov	x3, x11
	mov	x2, x10
	mov	x1, x9
	mov	x0, x8
	bl	f
	str	x0, [sp, 72]
	ldr	x1, [sp, 72]
	adrp	x0, .LC0
	add	x0, x0, :lo12:.LC0
	bl	printf
	mov	w0, 0
	mov	w1, w0
	adrp	x0, :got:__stack_chk_guard
	ldr	x0, [x0, :got_lo12:__stack_chk_guard]
	ldr	x3, [sp, 184]
	ldr	x2, [x0]
	subs	x3, x3, x2
	mov	x2, 0
	beq	.L7
	bl	__stack_chk_fail
.L7:
	mov	w0, w1
	ldp	x29, x30, [sp, 192]
	add	sp, sp, 208
	.cfi_restore 29
	.cfi_restore 30
	.cfi_def_cfa_offset 0
	ret
	.cfi_endproc
.LFE6:
	.size	main, .-main
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
