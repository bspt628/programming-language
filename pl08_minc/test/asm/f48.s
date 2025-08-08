  .arch armv8-a
  .text
  .align 2
.global f19
.type f19, %function
f19:
.cfi_startproc
  sub sp, sp, #192
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  str x2, [x29, #-24]
  str x3, [x29, #-32]
  str x4, [x29, #-40]
  str x5, [x29, #-48]
  str x6, [x29, #-56]
  str x7, [x29, #-64]
  ldr x0, [x29, #-16]
  b .L_epilogue_f19
.L_epilogue_f19:
  add sp, sp, #192
  ret
.cfi_endproc
.size f19, .-f19
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #0
  mov x29, sp
  mov x0, #1200
  str x0, [sp, #-16]!
  mov x0, #1100
  str x0, [sp, #-16]!
  mov x0, #1000
  str x0, [sp, #-16]!
  mov x0, #900
  str x0, [sp, #-16]!
  mov x0, #800
  str x0, [sp, #-16]!
  mov x0, #700
  str x0, [sp, #-16]!
  mov x0, #600
  str x0, [sp, #-16]!
  mov x0, #500
  str x0, [sp, #-16]!
  mov x0, #400
  str x0, [sp, #-16]!
  mov x0, #300
  str x0, [sp, #-16]!
  mov x0, #200
  str x0, [sp, #-16]!
  mov x0, #100
  str x0, [sp, #-16]!
  ldr x0, [sp], #16
  ldr x1, [sp], #16
  ldr x2, [sp], #16
  ldr x3, [sp], #16
  ldr x4, [sp], #16
  ldr x5, [sp], #16
  ldr x6, [sp], #16
  ldr x7, [sp], #16
  sub sp, sp, #64
  bl f19
  add sp, sp, #64
  add x0, x0, #10
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #0
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
