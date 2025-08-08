  .arch armv8-a
  .text
  .align 2
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #0
  mov x29, sp
  mov x0, #123
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #0
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
