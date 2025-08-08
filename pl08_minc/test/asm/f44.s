  .arch armv8-a
  .text
  .align 2
.global f01
.type f01, %function
f01:
.cfi_startproc
  sub sp, sp, #0
  mov x29, sp
  mov x0, #10
  neg x0, x0
  b .L_epilogue_f01
.L_epilogue_f01:
  add sp, sp, #0
  ret
.cfi_endproc
.size f01, .-f01
.global f
.type f, %function
f:
.cfi_startproc
  sub sp, sp, #32
  mov x29, sp
  str x0, [x29, #-8]
  bl f01
  add x0, x0, #1
  b .L_epilogue_f
.L_epilogue_f:
  add sp, sp, #32
  ret
.cfi_endproc
.size f, .-f
  .section .note.GNU-stack,"",@progbits
