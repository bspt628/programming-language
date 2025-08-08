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
  str x1, [x29, #-16]
  ldr x0, [x29, #-8]
  mov x1, x0
  ldr x0, [x29, #-16]
  sdiv x0, x1, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #32
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
