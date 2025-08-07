  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  stp x29, x30, [sp, #-48]!
  mov x29, sp
  sub sp, sp, #32
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  mov x0, #3
  str x0, [sp, #-16]!
  ldr x0, [x29, #-24]
  ldr x1, [sp], #16
  mul x0, x0, x1
  b .L_epilogue_f
.L_epilogue_f:
  mov sp, x29
  ldp x29, x30, [sp], 48
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
