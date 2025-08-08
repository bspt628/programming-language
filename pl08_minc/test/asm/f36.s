  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  stp x29, x30, [sp, #-16]!
  sub sp, sp, #48
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  str x2, [x29, #-24]
  ldr x0, [x29, #-8]
  mov x9, x0
  ldr x0, [x29, #-16]
  mov x10, x0
  ldr x0, [x29, #-24]
  cmp x10, x0
  cset x0, lt
  cmp x9, x0
  cset x0, eq
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #48
  ldp x29, x30, [sp], #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
