  .arch armv8-a
  .text
  .align 2
.global f07
.type f07, %function
f07:
.cfi_startproc
  stp x29, x30, [sp, #-16]!
  sub sp, sp, #16
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  ldr x9, [x29, #-8]
  ldr x1, [x29, #-16]
  add x0, x9, x1
  b .L_epilogue_f07
.L_epilogue_f07:
  add sp, sp, #16
  ldp x29, x30, [sp], #16
  ret
.cfi_endproc
.size f07, .-f07
.global f
.type f, %function
f:
.cfi_startproc
  stp x29, x30, [sp, #-16]!
  sub sp, sp, #16
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  ldr x0, [x29, #-16]
  str x0, [sp, #-16]!
  ldr x0, [x29, #-8]
  str x0, [sp, #-16]!
  ldr x0, [sp], #16
  ldr x1, [sp], #16
  bl f07
  add x0, x0, #1
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #16
  ldp x29, x30, [sp], #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
