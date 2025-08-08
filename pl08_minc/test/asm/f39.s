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
  ldr x0, [x29, #-8]
  add x0, x0, #2
  str x0, [x29, #-16]
  ldr x0, [x29, #-16]
  mul x0, x0, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #16
  ldp x29, x30, [sp], #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
