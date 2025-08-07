  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #16
  mov x29, sp
  mov x0, #10
  neg x0, x0
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #16
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
