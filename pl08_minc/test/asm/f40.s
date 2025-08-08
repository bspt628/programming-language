  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #64
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  str x2, [x29, #-24]
  ldr x0, [x29, #-8]
  cmp x0, #0
  beq .Lif_else_1
  ldr x9, [x29, #-16]
  ldr x1, [x29, #-24]
  add x0, x9, x1
  b .L_epilogue_f
  b .Lif_end_2
.Lif_else_1:
  ldr x9, [x29, #-16]
  ldr x1, [x29, #-24]
  mul x0, x9, x1
  b .L_epilogue_f
.Lif_end_2:
.L_epilogue_f:
  add sp, sp, #64
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
