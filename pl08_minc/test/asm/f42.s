  .arch armv8-a
  .text
  .align 2
.global sum2
.type sum2, %function
sum2:
.cfi_startproc
  sub sp, sp, #48
  mov x29, sp
  str x0, [x29, #-8]
  mov x0, #0
  str x0, [x29, #-16]
  mov x0, #0
  str x0, [x29, #-24]
.Lwhile_loop_1:
  ldr x9, [x29, #-16]
  ldr x0, [x29, #-8]
  mov x10, x0
  ldr x0, [x29, #-8]
  mul x0, x10, x0
  cmp x9, x0
  bge .Lwhile_end_2
  ldr x0, [x29, #-24]
  mov x10, x0
  ldr x0, [x29, #-16]
  add x0, x10, x0
  str x0, [x29, #-24]
  ldr x0, [x29, #-16]
  add x0, x0, #1
  str x0, [x29, #-16]
  b .Lwhile_loop_1
.Lwhile_end_2:
  ldr x0, [x29, #-24]
  b .L_epilogue_sum2
.L_epilogue_sum2:
  add sp, sp, #48
  ret
.cfi_endproc
.size sum2, .-sum2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #32
  mov x29, sp
  str x0, [x29, #-8]
  ldr x0, [x29, #-8]
  mov x1, #10000
  udiv x2, x0, x1
  mul x2, x2, x1
  sub x0, x0, x2
  str x0, [sp, #-16]!
  ldr x0, [sp], #16
  bl sum2
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #32
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
