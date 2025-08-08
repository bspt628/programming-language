  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  stp x29, x30, [sp, #-16]!
  sub sp, sp, #16
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  ldr x9, [x29, #-8]
  ldr x0, [x29, #-16]
  cmp x0, #0
  cset x0, eq
  mul x0, x9, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #16
  ldp x29, x30, [sp], #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
