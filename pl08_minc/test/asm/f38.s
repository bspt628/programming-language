  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #128
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  str x2, [x29, #-24]
  str x3, [x29, #-32]
  str x4, [x29, #-40]
  str x5, [x29, #-48]
  str x6, [x29, #-56]
  str x7, [x29, #-64]
  ldr x0, [x29, #-24]
  mov x12, x0
  ldr x0, [x29, #-32]
  mov x13, x0
  ldr x0, [x29, #-40]
  mul x0, x13, x0
  add x0, x12, x0
  mov x11, x0
  ldr x0, [x29, #-48]
  mov x12, x0
  ldr x0, [x29, #-56]
  mov x13, x0
  ldr x0, [x29, #-64]
  mul x0, x13, x0
  add x0, x12, x0
  cmp x11, x0
  cset x0, lt
  str x0, [x29, #-16]
  str x0, [x29, #-8]
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #128
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
