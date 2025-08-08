  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #16
  mov x29, sp
  str x0, [sp, #56]
  str x1, [sp, #48]
  ldr x0, [sp, #56]
  mov x1, x0
  ldr x0, [sp, #48]
  cmp x0, #0
  cset x0, eq
  mul x0, x1, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
