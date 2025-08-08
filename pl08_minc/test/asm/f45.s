  .arch armv8-a
  .text
  .align 2
.global f03
.type f03, %function
f03:
.cfi_startproc
  sub sp, sp, #32
  mov x29, sp
  str x0, [x29, #-8]
  ldr x0, [x29, #-8]
  b .L_epilogue_f03
.L_epilogue_f03:
  add sp, sp, #32
  ret
.cfi_endproc
.size f03, .-f03
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #32
  mov x29, sp
  str x0, [x29, #-8]
  ldr x0, [x29, #-8]
  str x0, [sp, #-16]!
  ldr x0, [sp], #16
  bl f03
  add x0, x0, #1
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #32
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
