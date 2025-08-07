  .text
f:
.globl f
  push %%rbp
  mov %%rsp, %%rbp
  sub $32, %rsp
  mov %rdi, -8(%rbp)
  mov %rsi, -16(%rbp)
  mov -16(%rbp), %rax
  push %%rax
  mov -8(%rbp), %rax
  pop %%r10
  add %%r10, %%rax
  mov %rax, -24(%rbp)
  mov $3, %rax
  push %%rax
  mov -24(%rbp), %rax
  pop %%r10
  imul %%r10, %%rax
  jmp .L_return_f
.L_return_f:
  leave
  ret