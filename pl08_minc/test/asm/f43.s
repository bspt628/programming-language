  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #32
  mov x29, sp
  str x0, [x29, #-8]
  mov x0, #2
  str x0, [x29, #-16]
  b .Lwhile_cond_2
.Lwhile_loop_1:
  ldr x10, [x29, #-8]
  ldr x1, [x29, #-16]
  mov x2, x1
  sdiv x1, x10, x1
  mul x1, x1, x2
  sub x0, x10, x1
  mov x9, x0
  mov x0, #0
  cmp x9, x0
  cset x0, eq
  cmp x0, #0
  beq .Lif_else_4
  mov x0, #0
  b .L_epilogue_f
  b .Lif_end_5
.Lif_else_4:
.Lif_end_5:
  ldr x0, [x29, #-16]
  add x0, x0, #1
  str x0, [x29, #-16]
.Lwhile_cond_2:
  ldr x0, [x29, #-8]
  mov x9, x0
  ldr x0, [x29, #-16]
  mul x0, x0, x0
  cmp x0, x9
  ble .Lwhile_loop_1
.Lwhile_end_3:
  mov x0, #1
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #32
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
