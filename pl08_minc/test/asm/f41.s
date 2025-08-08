  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  stp x29, x30, [sp, #-16]!
  sub sp, sp, #48
  mov x29, sp
  str x0, [x29, #-8]
  str x1, [x29, #-16]
  str x2, [x29, #-24]
  mov x0, #100
  str x0, [x29, #-32]
  ldr x0, [x29, #-8]
  mov x9, x0
  mov x0, #0
  cmp x9, x0
  cset x0, gt
  cmp x0, #0
  beq .Lif_else_1
  ldr x0, [x29, #-16]
  mov x9, x0
  mov x0, #0
  cmp x9, x0
  cset x0, gt
  cmp x0, #0
  beq .Lif_else_3
  mov x0, #200
  str x0, [x29, #-32]
  b .Lif_end_4
.Lif_else_3:
  mov x0, #300
  str x0, [x29, #-32]
.Lif_end_4:
  b .Lif_end_2
.Lif_else_1:
.Lif_end_2:
  ldr x0, [x29, #-32]
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #48
  ldp x29, x30, [sp], #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
