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
  mov x1, x0
  ldr x0, [x29, #-16]
  sub x0, x1, x0
  mov x1, x0
  ldr x0, [x29, #-24]
  sub x0, x1, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #64
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
