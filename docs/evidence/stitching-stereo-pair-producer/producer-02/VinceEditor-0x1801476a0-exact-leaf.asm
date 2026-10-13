
extracted/1.0.0.30839/VinceEditor.dll:     file format pei-x86-64


Disassembly of section .text:

00000001801476a0 <.text+0x1466a0>:
   1801476a0:	45 33 c0             	xor    r8d,r8d
   1801476a3:	48 8d 05 0e a0 56 00 	lea    rax,[rip+0x56a00e]        # 0x1806b16b8
   1801476aa:	48 89 01             	mov    QWORD PTR [rcx],rax
   1801476ad:	0f 57 c0             	xorps  xmm0,xmm0
   1801476b0:	33 c0                	xor    eax,eax
   1801476b2:	44 89 41 08          	mov    DWORD PTR [rcx+0x8],r8d
   1801476b6:	0f 11 41 0c          	movups XMMWORD PTR [rcx+0xc],xmm0
   1801476ba:	48 89 41 1c          	mov    QWORD PTR [rcx+0x1c],rax
   1801476be:	66 89 41 38          	mov    WORD PTR [rcx+0x38],ax
   1801476c2:	48 8b c1             	mov    rax,rcx
   1801476c5:	4c 89 41 24          	mov    QWORD PTR [rcx+0x24],r8
   1801476c9:	44 89 41 2c          	mov    DWORD PTR [rcx+0x2c],r8d
   1801476cd:	48 89 51 30          	mov    QWORD PTR [rcx+0x30],rdx
   1801476d1:	c3                   	ret
