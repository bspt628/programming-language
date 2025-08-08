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
  b .Lwhile_cond_2
.Lwhile_loop_1:
  ldr x10, [x29, #-24]
  ldr x1, [x29, #-16]
  add x0, x10, x1
  str x0, [x29, #-24]
  ldr x0, [x29, #-16]
  add x0, x0, #1
  str x0, [x29, #-16]
.Lwhile_cond_2:
  ldr x0, [x29, #-8]
  mul x0, x0, x0
  mov x9, x0
  ldr x0, [x29, #-16]
  cmp x0, x9
  blt .Lwhile_loop_1
.Lwhile_end_3:
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
  sdiv x2, x0, x1
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
