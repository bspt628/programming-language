  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #64
  mov x29, sp
  str x0, [sp, #56]
  str x1, [sp, #48]
  str x2, [sp, #40]
  str x3, [sp, #32]
  str x4, [sp, #24]
  str x5, [sp, #16]
  str x6, [sp, #8]
  str x7, [sp, #0]
  ldr x0, [sp, #48]
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #64
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
