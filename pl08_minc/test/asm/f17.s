  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #32
  mov x29, sp
  str x0, [sp, #56]
  str x1, [sp, #48]
  str x2, [sp, #40]
  ldr x1, [sp, #56]
  mov x1, x0
  ldr x0, [sp, #48]
  add x0, x1, x0
  mov x1, x0
  ldr x0, [sp, #40]
  add x0, x1, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #32
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
