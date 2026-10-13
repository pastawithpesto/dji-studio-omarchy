
extracted/1.0.0.30839/VinceEditor.dll:     file format pei-x86-64


Disassembly of section .text:

0000000180198080 <.text+0x197080>:
   180198080:	48 89 5c 24 10       	mov    QWORD PTR [rsp+0x10],rbx
   180198085:	48 89 74 24 18       	mov    QWORD PTR [rsp+0x18],rsi
   18019808a:	48 89 7c 24 20       	mov    QWORD PTR [rsp+0x20],rdi
   18019808f:	55                   	push   rbp
   180198090:	41 54                	push   r12
   180198092:	41 55                	push   r13
   180198094:	41 56                	push   r14
   180198096:	41 57                	push   r15
   180198098:	48 8d ac 24 c0 fe ff 	lea    rbp,[rsp-0x140]
   18019809f:	ff 
   1801980a0:	48 81 ec 40 02 00 00 	sub    rsp,0x240
   1801980a7:	48 8b 05 fa 84 86 00 	mov    rax,QWORD PTR [rip+0x8684fa]        # 0x180a005a8
   1801980ae:	48 33 c4             	xor    rax,rsp
   1801980b1:	48 89 85 38 01 00 00 	mov    QWORD PTR [rbp+0x138],rax
   1801980b8:	48 8b f9             	mov    rdi,rcx
   1801980bb:	48 89 4c 24 30       	mov    QWORD PTR [rsp+0x30],rcx
   1801980c0:	e8 fb 9c 0e 00       	call   0x180281dc0
   1801980c5:	90                   	nop
   1801980c6:	48 8d 05 3b 23 52 00 	lea    rax,[rip+0x52233b]        # 0x1806ba408
   1801980cd:	48 89 07             	mov    QWORD PTR [rdi],rax
   1801980d0:	33 db                	xor    ebx,ebx
   1801980d2:	89 9f 40 04 00 00    	mov    DWORD PTR [rdi+0x440],ebx
   1801980d8:	8d 4b 28             	lea    ecx,[rbx+0x28]
   1801980db:	e8 74 3a 4b 00       	call   0x18064bb54
   1801980e0:	48 89 44 24 20       	mov    QWORD PTR [rsp+0x20],rax
   1801980e5:	48 85 c0             	test   rax,rax
   1801980e8:	74 0a                	je     0x1801980f4
   1801980ea:	48 8b c8             	mov    rcx,rax
   1801980ed:	e8 8e ee ff ff       	call   0x180196f80
   1801980f2:	eb 03                	jmp    0x1801980f7
   1801980f4:	48 8b c3             	mov    rax,rbx
   1801980f7:	48 89 87 48 04 00 00 	mov    QWORD PTR [rdi+0x448],rax
   1801980fe:	b9 50 0a 00 00       	mov    ecx,0xa50
   180198103:	e8 4c 3a 4b 00       	call   0x18064bb54
   180198108:	48 89 44 24 20       	mov    QWORD PTR [rsp+0x20],rax
   18019810d:	48 85 c0             	test   rax,rax
   180198110:	74 13                	je     0x180198125
   180198112:	48 8b 97 48 04 00 00 	mov    rdx,QWORD PTR [rdi+0x448]
   180198119:	48 8b c8             	mov    rcx,rax
   18019811c:	e8 1f c7 f9 ff       	call   0x180134840
   180198121:	33 c9                	xor    ecx,ecx
   180198123:	eb 04                	jmp    0x180198129
   180198125:	33 c9                	xor    ecx,ecx
   180198127:	8b c1                	mov    eax,ecx
   180198129:	48 89 87 50 04 00 00 	mov    QWORD PTR [rdi+0x450],rax
   180198130:	48 89 8f 58 04 00 00 	mov    QWORD PTR [rdi+0x458],rcx
   180198137:	48 c7 87 60 04 00 00 	mov    QWORD PTR [rdi+0x460],0x0
   18019813e:	00 00 00 00 
   180198142:	89 8f 68 04 00 00    	mov    DWORD PTR [rdi+0x468],ecx
   180198148:	48 c7 87 70 04 00 00 	mov    QWORD PTR [rdi+0x470],0x0
   18019814f:	00 00 00 00 
   180198153:	48 89 8f 78 04 00 00 	mov    QWORD PTR [rdi+0x478],rcx
   18019815a:	48 c7 87 80 04 00 00 	mov    QWORD PTR [rdi+0x480],0x0
   180198161:	00 00 00 00 
   180198165:	89 8f 88 04 00 00    	mov    DWORD PTR [rdi+0x488],ecx
   18019816b:	48 c7 87 90 04 00 00 	mov    QWORD PTR [rdi+0x490],0x0
   180198172:	00 00 00 00 
   180198176:	0f 28 05 13 09 4e 00 	movaps xmm0,XMMWORD PTR [rip+0x4e0913]        # 0x180678a90
   18019817d:	0f 11 87 a0 04 00 00 	movups XMMWORD PTR [rdi+0x4a0],xmm0
   180198184:	0f 57 c9             	xorps  xmm1,xmm1
   180198187:	c7 44 24 28 00 00 00 	mov    DWORD PTR [rsp+0x28],0x0
   18019818e:	00 
   18019818f:	0f 57 c0             	xorps  xmm0,xmm0
   180198192:	0f 14 c1             	unpcklps xmm0,xmm1
   180198195:	f2 0f 11 87 b0 04 00 	movsd  QWORD PTR [rdi+0x4b0],xmm0
   18019819c:	00 
   18019819d:	8b 44 24 28          	mov    eax,DWORD PTR [rsp+0x28]
   1801981a1:	89 87 b8 04 00 00    	mov    DWORD PTR [rdi+0x4b8],eax
   1801981a7:	c7 44 24 28 00 00 00 	mov    DWORD PTR [rsp+0x28],0x0
   1801981ae:	00 
   1801981af:	0f 57 c0             	xorps  xmm0,xmm0
   1801981b2:	0f 14 c1             	unpcklps xmm0,xmm1
   1801981b5:	f2 0f 11 87 bc 04 00 	movsd  QWORD PTR [rdi+0x4bc],xmm0
   1801981bc:	00 
   1801981bd:	8b 44 24 28          	mov    eax,DWORD PTR [rsp+0x28]
   1801981c1:	89 87 c4 04 00 00    	mov    DWORD PTR [rdi+0x4c4],eax
   1801981c7:	c7 87 c8 04 00 00 39 	mov    DWORD PTR [rdi+0x4c8],0x3fe38e39
   1801981ce:	8e e3 3f 
   1801981d1:	48 c7 87 cc 04 00 00 	mov    QWORD PTR [rdi+0x4cc],0x42b40000
   1801981d8:	00 00 b4 42 
   1801981dc:	48 c7 87 d4 04 00 00 	mov    QWORD PTR [rdi+0x4d4],0x0
   1801981e3:	00 00 00 00 
   1801981e7:	48 c7 87 dc 04 00 00 	mov    QWORD PTR [rdi+0x4dc],0x0
   1801981ee:	00 00 00 00 
   1801981f2:	48 c7 87 e4 04 00 00 	mov    QWORD PTR [rdi+0x4e4],0x0
   1801981f9:	00 00 00 00 
   1801981fd:	48 c7 87 ec 04 00 00 	mov    QWORD PTR [rdi+0x4ec],0x0
   180198204:	00 00 00 00 
   180198208:	48 c7 87 f4 04 00 00 	mov    QWORD PTR [rdi+0x4f4],0x0
   18019820f:	00 00 00 00 
   180198213:	48 c7 87 fc 04 00 00 	mov    QWORD PTR [rdi+0x4fc],0x0
   18019821a:	00 00 00 00 
   18019821e:	48 c7 87 04 05 00 00 	mov    QWORD PTR [rdi+0x504],0x0
   180198225:	00 00 00 00 
   180198229:	c7 87 0c 05 00 00 01 	mov    DWORD PTR [rdi+0x50c],0x1
   180198230:	00 00 00 
   180198233:	48 c7 87 10 05 00 00 	mov    QWORD PTR [rdi+0x510],0x1
   18019823a:	01 00 00 00 
   18019823e:	48 c7 87 18 05 00 00 	mov    QWORD PTR [rdi+0x518],0x0
   180198245:	00 00 00 00 
   180198249:	48 c7 87 20 05 00 00 	mov    QWORD PTR [rdi+0x520],0x0
   180198250:	00 00 00 00 
   180198254:	89 8f 28 05 00 00    	mov    DWORD PTR [rdi+0x528],ecx
   18019825a:	48 c7 87 2c 05 00 00 	mov    QWORD PTR [rdi+0x52c],0x7
   180198261:	07 00 00 00 
   180198265:	48 c7 87 34 05 00 00 	mov    QWORD PTR [rdi+0x534],0x0
   18019826c:	00 00 00 00 
   180198270:	48 c7 87 3c 05 00 00 	mov    QWORD PTR [rdi+0x53c],0x0
   180198277:	00 00 00 00 
   18019827b:	48 c7 87 4c 05 00 00 	mov    QWORD PTR [rdi+0x54c],0x0
   180198282:	00 00 00 00 
   180198286:	89 8f 54 05 00 00    	mov    DWORD PTR [rdi+0x554],ecx
   18019828c:	c7 87 58 05 00 00 00 	mov    DWORD PTR [rdi+0x558],0x42f00000
   180198293:	00 f0 42 
   180198296:	c7 87 5c 05 00 00 0a 	mov    DWORD PTR [rdi+0x55c],0x3ca3d70a
   18019829d:	d7 a3 3c 
   1801982a0:	48 c7 87 60 05 00 00 	mov    QWORD PTR [rdi+0x560],0x3da3d70a
   1801982a7:	0a d7 a3 3d 
   1801982ab:	48 c7 87 68 05 00 00 	mov    QWORD PTR [rdi+0x568],0x0
   1801982b2:	00 00 00 00 
   1801982b6:	89 8f 70 05 00 00    	mov    DWORD PTR [rdi+0x570],ecx
   1801982bc:	48 8d 8f 78 05 00 00 	lea    rcx,[rdi+0x578]
   1801982c3:	ba 02 00 00 00       	mov    edx,0x2
   1801982c8:	e8 8b 4f 4b 00       	call   0x18064d258
   1801982cd:	90                   	nop
   1801982ce:	33 c0                	xor    eax,eax
   1801982d0:	89 87 c8 05 00 00    	mov    DWORD PTR [rdi+0x5c8],eax
   1801982d6:	48 89 87 f0 05 00 00 	mov    QWORD PTR [rdi+0x5f0],rax
   1801982dd:	48 89 87 f8 05 00 00 	mov    QWORD PTR [rdi+0x5f8],rax
   1801982e4:	48 89 87 00 06 00 00 	mov    QWORD PTR [rdi+0x600],rax
   1801982eb:	48 89 87 08 06 00 00 	mov    QWORD PTR [rdi+0x608],rax
   1801982f2:	48 89 87 10 06 00 00 	mov    QWORD PTR [rdi+0x610],rax
   1801982f9:	48 89 87 18 06 00 00 	mov    QWORD PTR [rdi+0x618],rax
   180198300:	48 89 87 40 06 00 00 	mov    QWORD PTR [rdi+0x640],rax
   180198307:	48 89 87 48 06 00 00 	mov    QWORD PTR [rdi+0x648],rax
   18019830e:	48 89 87 50 06 00 00 	mov    QWORD PTR [rdi+0x650],rax
   180198315:	48 89 87 78 06 00 00 	mov    QWORD PTR [rdi+0x678],rax
   18019831c:	48 89 87 80 06 00 00 	mov    QWORD PTR [rdi+0x680],rax
   180198323:	48 89 87 88 06 00 00 	mov    QWORD PTR [rdi+0x688],rax
   18019832a:	48 89 87 90 06 00 00 	mov    QWORD PTR [rdi+0x690],rax
   180198331:	48 89 87 98 06 00 00 	mov    QWORD PTR [rdi+0x698],rax
   180198338:	48 89 87 a0 06 00 00 	mov    QWORD PTR [rdi+0x6a0],rax
   18019833f:	48 89 87 c8 06 00 00 	mov    QWORD PTR [rdi+0x6c8],rax
   180198346:	48 89 87 d0 06 00 00 	mov    QWORD PTR [rdi+0x6d0],rax
   18019834d:	48 89 87 d8 06 00 00 	mov    QWORD PTR [rdi+0x6d8],rax
   180198354:	48 89 87 38 07 00 00 	mov    QWORD PTR [rdi+0x738],rax
   18019835b:	48 89 87 40 07 00 00 	mov    QWORD PTR [rdi+0x740],rax
   180198362:	48 89 87 48 07 00 00 	mov    QWORD PTR [rdi+0x748],rax
   180198369:	48 89 87 b0 07 00 00 	mov    QWORD PTR [rdi+0x7b0],rax
   180198370:	48 89 87 b8 07 00 00 	mov    QWORD PTR [rdi+0x7b8],rax
   180198377:	48 89 87 c0 07 00 00 	mov    QWORD PTR [rdi+0x7c0],rax
   18019837e:	48 89 87 f0 07 00 00 	mov    QWORD PTR [rdi+0x7f0],rax
   180198385:	48 89 87 f8 07 00 00 	mov    QWORD PTR [rdi+0x7f8],rax
   18019838c:	48 89 87 00 08 00 00 	mov    QWORD PTR [rdi+0x800],rax
   180198393:	48 89 87 08 08 00 00 	mov    QWORD PTR [rdi+0x808],rax
   18019839a:	48 89 87 10 08 00 00 	mov    QWORD PTR [rdi+0x810],rax
   1801983a1:	48 89 87 18 08 00 00 	mov    QWORD PTR [rdi+0x818],rax
   1801983a8:	48 89 87 40 08 00 00 	mov    QWORD PTR [rdi+0x840],rax
   1801983af:	48 89 87 48 08 00 00 	mov    QWORD PTR [rdi+0x848],rax
   1801983b6:	48 89 87 50 08 00 00 	mov    QWORD PTR [rdi+0x850],rax
   1801983bd:	48 89 87 78 08 00 00 	mov    QWORD PTR [rdi+0x878],rax
   1801983c4:	48 89 87 80 08 00 00 	mov    QWORD PTR [rdi+0x880],rax
   1801983cb:	48 89 87 88 08 00 00 	mov    QWORD PTR [rdi+0x888],rax
   1801983d2:	48 89 87 90 08 00 00 	mov    QWORD PTR [rdi+0x890],rax
   1801983d9:	48 89 87 98 08 00 00 	mov    QWORD PTR [rdi+0x898],rax
   1801983e0:	48 89 87 a0 08 00 00 	mov    QWORD PTR [rdi+0x8a0],rax
   1801983e7:	48 89 87 c8 08 00 00 	mov    QWORD PTR [rdi+0x8c8],rax
   1801983ee:	48 89 87 d0 08 00 00 	mov    QWORD PTR [rdi+0x8d0],rax
   1801983f5:	48 89 87 d8 08 00 00 	mov    QWORD PTR [rdi+0x8d8],rax
   1801983fc:	48 89 87 38 09 00 00 	mov    QWORD PTR [rdi+0x938],rax
   180198403:	48 89 87 40 09 00 00 	mov    QWORD PTR [rdi+0x940],rax
   18019840a:	48 89 87 48 09 00 00 	mov    QWORD PTR [rdi+0x948],rax
   180198411:	48 89 87 b0 09 00 00 	mov    QWORD PTR [rdi+0x9b0],rax
   180198418:	48 89 87 b8 09 00 00 	mov    QWORD PTR [rdi+0x9b8],rax
   18019841f:	48 89 87 c0 09 00 00 	mov    QWORD PTR [rdi+0x9c0],rax
   180198426:	88 87 d0 09 00 00    	mov    BYTE PTR [rdi+0x9d0],al
   18019842c:	48 89 44 24 38       	mov    QWORD PTR [rsp+0x38],rax
   180198431:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198438:	00 00 
   18019843a:	48 c7 44 24 48 04 00 	mov    QWORD PTR [rsp+0x48],0x4
   180198441:	00 00 
   180198443:	8b 05 07 32 4f 00    	mov    eax,DWORD PTR [rip+0x4f3207]        # 0x18068b650
   180198449:	89 44 24 38          	mov    DWORD PTR [rsp+0x38],eax
   18019844d:	c6 44 24 3c 00       	mov    BYTE PTR [rsp+0x3c],0x0
   180198452:	4c 8d 87 58 04 00 00 	lea    r8,[rdi+0x458]
   180198459:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019845e:	48 8b cf             	mov    rcx,rdi
   180198461:	e8 fa a4 0e 00       	call   0x180282960
   180198466:	90                   	nop
   180198467:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   18019846c:	48 83 fa 10          	cmp    rdx,0x10
   180198470:	72 35                	jb     0x1801984a7
   180198472:	48 ff c2             	inc    rdx
   180198475:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   18019847a:	48 8b c1             	mov    rax,rcx
   18019847d:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198484:	72 1c                	jb     0x1801984a2
   180198486:	48 83 c2 27          	add    rdx,0x27
   18019848a:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   18019848e:	48 2b c1             	sub    rax,rcx
   180198491:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198495:	48 83 f8 1f          	cmp    rax,0x1f
   180198499:	76 07                	jbe    0x1801984a2
   18019849b:	ff 15 af 7d 4d 00    	call   QWORD PTR [rip+0x4d7daf]        # 0x180670250
   1801984a1:	cc                   	int3
   1801984a2:	e8 e9 63 ec ff       	call   0x18005e890
   1801984a7:	33 db                	xor    ebx,ebx
   1801984a9:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   1801984ae:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   1801984b5:	00 00 
   1801984b7:	48 c7 44 24 48 04 00 	mov    QWORD PTR [rsp+0x48],0x4
   1801984be:	00 00 
   1801984c0:	8b 05 32 1f 52 00    	mov    eax,DWORD PTR [rip+0x521f32]        # 0x1806ba3f8
   1801984c6:	89 44 24 38          	mov    DWORD PTR [rsp+0x38],eax
   1801984ca:	88 5c 24 3c          	mov    BYTE PTR [rsp+0x3c],bl
   1801984ce:	4c 8d 87 78 04 00 00 	lea    r8,[rdi+0x478]
   1801984d5:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801984da:	48 8b cf             	mov    rcx,rdi
   1801984dd:	e8 7e a4 0e 00       	call   0x180282960
   1801984e2:	90                   	nop
   1801984e3:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   1801984e8:	48 83 fa 10          	cmp    rdx,0x10
   1801984ec:	72 36                	jb     0x180198524
   1801984ee:	48 ff c2             	inc    rdx
   1801984f1:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   1801984f6:	48 8b c1             	mov    rax,rcx
   1801984f9:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198500:	72 1c                	jb     0x18019851e
   180198502:	48 83 c2 27          	add    rdx,0x27
   180198506:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   18019850a:	48 2b c1             	sub    rax,rcx
   18019850d:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198511:	48 83 f8 1f          	cmp    rax,0x1f
   180198515:	76 07                	jbe    0x18019851e
   180198517:	ff 15 33 7d 4d 00    	call   QWORD PTR [rip+0x4d7d33]        # 0x180670250
   18019851d:	cc                   	int3
   18019851e:	e8 6d 63 ec ff       	call   0x18005e890
   180198523:	90                   	nop
   180198524:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   18019852b:	00 00 
   18019852d:	48 c7 44 24 48 0a 00 	mov    QWORD PTR [rsp+0x48],0xa
   180198534:	00 00 
   180198536:	f2 0f 10 05 c2 1f 52 	movsd  xmm0,QWORD PTR [rip+0x521fc2]        # 0x1806ba500
   18019853d:	00 
   18019853e:	f2 0f 11 44 24 38    	movsd  QWORD PTR [rsp+0x38],xmm0
   180198544:	0f b7 05 bd 1f 52 00 	movzx  eax,WORD PTR [rip+0x521fbd]        # 0x1806ba508
   18019854b:	66 89 44 24 40       	mov    WORD PTR [rsp+0x40],ax
   180198550:	c6 44 24 42 00       	mov    BYTE PTR [rsp+0x42],0x0
   180198555:	4c 8d 87 40 04 00 00 	lea    r8,[rdi+0x440]
   18019855c:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198561:	48 8b cf             	mov    rcx,rdi
   180198564:	e8 17 a3 0e 00       	call   0x180282880
   180198569:	90                   	nop
   18019856a:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   18019856f:	48 83 fa 10          	cmp    rdx,0x10
   180198573:	72 36                	jb     0x1801985ab
   180198575:	48 ff c2             	inc    rdx
   180198578:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   18019857d:	48 8b c1             	mov    rax,rcx
   180198580:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198587:	72 1c                	jb     0x1801985a5
   180198589:	48 83 c2 27          	add    rdx,0x27
   18019858d:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198591:	48 2b c1             	sub    rax,rcx
   180198594:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198598:	48 83 f8 1f          	cmp    rax,0x1f
   18019859c:	76 07                	jbe    0x1801985a5
   18019859e:	ff 15 ac 7c 4d 00    	call   QWORD PTR [rip+0x4d7cac]        # 0x180670250
   1801985a4:	cc                   	int3
   1801985a5:	e8 e6 62 ec ff       	call   0x18005e890
   1801985aa:	90                   	nop
   1801985ab:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   1801985b2:	00 00 
   1801985b4:	48 c7 44 24 48 0a 00 	mov    QWORD PTR [rsp+0x48],0xa
   1801985bb:	00 00 
   1801985bd:	f2 0f 10 05 4b 1f 52 	movsd  xmm0,QWORD PTR [rip+0x521f4b]        # 0x1806ba510
   1801985c4:	00 
   1801985c5:	f2 0f 11 44 24 38    	movsd  QWORD PTR [rsp+0x38],xmm0
   1801985cb:	0f b7 05 46 1f 52 00 	movzx  eax,WORD PTR [rip+0x521f46]        # 0x1806ba518
   1801985d2:	66 89 44 24 40       	mov    WORD PTR [rsp+0x40],ax
   1801985d7:	c6 44 24 42 00       	mov    BYTE PTR [rsp+0x42],0x0
   1801985dc:	4c 8d 87 a0 04 00 00 	lea    r8,[rdi+0x4a0]
   1801985e3:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801985e8:	48 8b cf             	mov    rcx,rdi
   1801985eb:	e8 d0 a5 0e 00       	call   0x180282bc0
   1801985f0:	90                   	nop
   1801985f1:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   1801985f6:	48 83 fa 10          	cmp    rdx,0x10
   1801985fa:	72 35                	jb     0x180198631
   1801985fc:	48 ff c2             	inc    rdx
   1801985ff:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198604:	48 8b c1             	mov    rax,rcx
   180198607:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   18019860e:	72 1c                	jb     0x18019862c
   180198610:	48 83 c2 27          	add    rdx,0x27
   180198614:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198618:	48 2b c1             	sub    rax,rcx
   18019861b:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   18019861f:	48 83 f8 1f          	cmp    rax,0x1f
   180198623:	76 07                	jbe    0x18019862c
   180198625:	ff 15 25 7c 4d 00    	call   QWORD PTR [rip+0x4d7c25]        # 0x180670250
   18019862b:	cc                   	int3
   18019862c:	e8 5f 62 ec ff       	call   0x18005e890
   180198631:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198636:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   18019863b:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198642:	00 00 
   180198644:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198649:	41 b8 10 00 00 00    	mov    r8d,0x10
   18019864f:	48 8d 15 ca 1e 52 00 	lea    rdx,[rip+0x521eca]        # 0x1806ba520
   180198656:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   18019865b:	e8 50 0d e8 ff       	call   0x1800193b0
   180198660:	90                   	nop
   180198661:	4c 8d 87 b0 04 00 00 	lea    r8,[rdi+0x4b0]
   180198668:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019866d:	48 8b cf             	mov    rcx,rdi
   180198670:	e8 eb a4 0e 00       	call   0x180282b60
   180198675:	90                   	nop
   180198676:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   18019867b:	48 83 fa 10          	cmp    rdx,0x10
   18019867f:	72 35                	jb     0x1801986b6
   180198681:	48 ff c2             	inc    rdx
   180198684:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198689:	48 8b c1             	mov    rax,rcx
   18019868c:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198693:	72 1c                	jb     0x1801986b1
   180198695:	48 83 c2 27          	add    rdx,0x27
   180198699:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   18019869d:	48 2b c1             	sub    rax,rcx
   1801986a0:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   1801986a4:	48 83 f8 1f          	cmp    rax,0x1f
   1801986a8:	76 07                	jbe    0x1801986b1
   1801986aa:	ff 15 a0 7b 4d 00    	call   QWORD PTR [rip+0x4d7ba0]        # 0x180670250
   1801986b0:	cc                   	int3
   1801986b1:	e8 da 61 ec ff       	call   0x18005e890
   1801986b6:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   1801986bb:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   1801986c0:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   1801986c7:	00 00 
   1801986c9:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   1801986ce:	41 b8 0c 00 00 00    	mov    r8d,0xc
   1801986d4:	48 8d 15 55 05 4f 00 	lea    rdx,[rip+0x4f0555]        # 0x180688c30
   1801986db:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801986e0:	e8 cb 0c e8 ff       	call   0x1800193b0
   1801986e5:	90                   	nop
   1801986e6:	4c 8d 87 c8 04 00 00 	lea    r8,[rdi+0x4c8]
   1801986ed:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801986f2:	48 8b cf             	mov    rcx,rdi
   1801986f5:	e8 36 a1 0e 00       	call   0x180282830
   1801986fa:	90                   	nop
   1801986fb:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198700:	48 83 fa 10          	cmp    rdx,0x10
   180198704:	72 35                	jb     0x18019873b
   180198706:	48 ff c2             	inc    rdx
   180198709:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   18019870e:	48 8b c1             	mov    rax,rcx
   180198711:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198718:	72 1c                	jb     0x180198736
   18019871a:	48 83 c2 27          	add    rdx,0x27
   18019871e:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198722:	48 2b c1             	sub    rax,rcx
   180198725:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198729:	48 83 f8 1f          	cmp    rax,0x1f
   18019872d:	76 07                	jbe    0x180198736
   18019872f:	ff 15 1b 7b 4d 00    	call   QWORD PTR [rip+0x4d7b1b]        # 0x180670250
   180198735:	cc                   	int3
   180198736:	e8 55 61 ec ff       	call   0x18005e890
   18019873b:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198740:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198745:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   18019874c:	00 00 
   18019874e:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198753:	41 b8 03 00 00 00    	mov    r8d,0x3
   180198759:	48 8d 15 d4 1d 52 00 	lea    rdx,[rip+0x521dd4]        # 0x1806ba534
   180198760:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198765:	e8 46 0c e8 ff       	call   0x1800193b0
   18019876a:	90                   	nop
   18019876b:	4c 8d 87 bc 04 00 00 	lea    r8,[rdi+0x4bc]
   180198772:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198777:	48 8b cf             	mov    rcx,rdi
   18019877a:	e8 e1 a3 0e 00       	call   0x180282b60
   18019877f:	90                   	nop
   180198780:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198785:	48 83 fa 10          	cmp    rdx,0x10
   180198789:	72 35                	jb     0x1801987c0
   18019878b:	48 ff c2             	inc    rdx
   18019878e:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198793:	48 8b c1             	mov    rax,rcx
   180198796:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   18019879d:	72 1c                	jb     0x1801987bb
   18019879f:	48 83 c2 27          	add    rdx,0x27
   1801987a3:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   1801987a7:	48 2b c1             	sub    rax,rcx
   1801987aa:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   1801987ae:	48 83 f8 1f          	cmp    rax,0x1f
   1801987b2:	76 07                	jbe    0x1801987bb
   1801987b4:	ff 15 96 7a 4d 00    	call   QWORD PTR [rip+0x4d7a96]        # 0x180670250
   1801987ba:	cc                   	int3
   1801987bb:	e8 d0 60 ec ff       	call   0x18005e890
   1801987c0:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   1801987c5:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   1801987ca:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   1801987d1:	00 00 
   1801987d3:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   1801987d8:	41 b8 03 00 00 00    	mov    r8d,0x3
   1801987de:	48 8d 15 37 15 4e 00 	lea    rdx,[rip+0x4e1537]        # 0x180679d1c
   1801987e5:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801987ea:	e8 c1 0b e8 ff       	call   0x1800193b0
   1801987ef:	90                   	nop
   1801987f0:	4c 8d 87 cc 04 00 00 	lea    r8,[rdi+0x4cc]
   1801987f7:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801987fc:	48 8b cf             	mov    rcx,rdi
   1801987ff:	e8 2c a0 0e 00       	call   0x180282830
   180198804:	90                   	nop
   180198805:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   18019880a:	48 83 fa 10          	cmp    rdx,0x10
   18019880e:	72 35                	jb     0x180198845
   180198810:	48 ff c2             	inc    rdx
   180198813:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198818:	48 8b c1             	mov    rax,rcx
   18019881b:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198822:	72 1c                	jb     0x180198840
   180198824:	48 83 c2 27          	add    rdx,0x27
   180198828:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   18019882c:	48 2b c1             	sub    rax,rcx
   18019882f:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198833:	48 83 f8 1f          	cmp    rax,0x1f
   180198837:	76 07                	jbe    0x180198840
   180198839:	ff 15 11 7a 4d 00    	call   QWORD PTR [rip+0x4d7a11]        # 0x180670250
   18019883f:	cc                   	int3
   180198840:	e8 4b 60 ec ff       	call   0x18005e890
   180198845:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   18019884a:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   18019884f:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198856:	00 00 
   180198858:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   18019885d:	41 b8 0a 00 00 00    	mov    r8d,0xa
   180198863:	48 8d 15 a6 14 4e 00 	lea    rdx,[rip+0x4e14a6]        # 0x180679d10
   18019886a:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   18019886f:	e8 3c 0b e8 ff       	call   0x1800193b0
   180198874:	90                   	nop
   180198875:	4c 8d 87 d0 04 00 00 	lea    r8,[rdi+0x4d0]
   18019887c:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198881:	48 8b cf             	mov    rcx,rdi
   180198884:	e8 f7 9f 0e 00       	call   0x180282880
   180198889:	90                   	nop
   18019888a:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   18019888f:	48 83 fa 10          	cmp    rdx,0x10
   180198893:	72 35                	jb     0x1801988ca
   180198895:	48 ff c2             	inc    rdx
   180198898:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   18019889d:	48 8b c1             	mov    rax,rcx
   1801988a0:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   1801988a7:	72 1c                	jb     0x1801988c5
   1801988a9:	48 83 c2 27          	add    rdx,0x27
   1801988ad:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   1801988b1:	48 2b c1             	sub    rax,rcx
   1801988b4:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   1801988b8:	48 83 f8 1f          	cmp    rax,0x1f
   1801988bc:	76 07                	jbe    0x1801988c5
   1801988be:	ff 15 8c 79 4d 00    	call   QWORD PTR [rip+0x4d798c]        # 0x180670250
   1801988c4:	cc                   	int3
   1801988c5:	e8 c6 5f ec ff       	call   0x18005e890
   1801988ca:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   1801988cf:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   1801988d4:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   1801988db:	00 00 
   1801988dd:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   1801988e2:	41 b8 0b 00 00 00    	mov    r8d,0xb
   1801988e8:	48 8d 15 19 0a 4e 00 	lea    rdx,[rip+0x4e0a19]        # 0x180679308
   1801988ef:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801988f4:	e8 b7 0a e8 ff       	call   0x1800193b0
   1801988f9:	90                   	nop
   1801988fa:	4c 8d 87 d4 04 00 00 	lea    r8,[rdi+0x4d4]
   180198901:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198906:	48 8b cf             	mov    rcx,rdi
   180198909:	e8 72 9f 0e 00       	call   0x180282880
   18019890e:	90                   	nop
   18019890f:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198914:	48 83 fa 10          	cmp    rdx,0x10
   180198918:	72 35                	jb     0x18019894f
   18019891a:	48 ff c2             	inc    rdx
   18019891d:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198922:	48 8b c1             	mov    rax,rcx
   180198925:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   18019892c:	72 1c                	jb     0x18019894a
   18019892e:	48 83 c2 27          	add    rdx,0x27
   180198932:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198936:	48 2b c1             	sub    rax,rcx
   180198939:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   18019893d:	48 83 f8 1f          	cmp    rax,0x1f
   180198941:	76 07                	jbe    0x18019894a
   180198943:	ff 15 07 79 4d 00    	call   QWORD PTR [rip+0x4d7907]        # 0x180670250
   180198949:	cc                   	int3
   18019894a:	e8 41 5f ec ff       	call   0x18005e890
   18019894f:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198954:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198959:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198960:	00 00 
   180198962:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198967:	41 b8 0d 00 00 00    	mov    r8d,0xd
   18019896d:	48 8d 15 c4 1b 52 00 	lea    rdx,[rip+0x521bc4]        # 0x1806ba538
   180198974:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198979:	e8 32 0a e8 ff       	call   0x1800193b0
   18019897e:	90                   	nop
   18019897f:	4c 8d 87 d8 04 00 00 	lea    r8,[rdi+0x4d8]
   180198986:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019898b:	48 8b cf             	mov    rcx,rdi
   18019898e:	e8 ed 9e 0e 00       	call   0x180282880
   180198993:	90                   	nop
   180198994:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198999:	48 83 fa 10          	cmp    rdx,0x10
   18019899d:	72 35                	jb     0x1801989d4
   18019899f:	48 ff c2             	inc    rdx
   1801989a2:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   1801989a7:	48 8b c1             	mov    rax,rcx
   1801989aa:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   1801989b1:	72 1c                	jb     0x1801989cf
   1801989b3:	48 83 c2 27          	add    rdx,0x27
   1801989b7:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   1801989bb:	48 2b c1             	sub    rax,rcx
   1801989be:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   1801989c2:	48 83 f8 1f          	cmp    rax,0x1f
   1801989c6:	76 07                	jbe    0x1801989cf
   1801989c8:	ff 15 82 78 4d 00    	call   QWORD PTR [rip+0x4d7882]        # 0x180670250
   1801989ce:	cc                   	int3
   1801989cf:	e8 bc 5e ec ff       	call   0x18005e890
   1801989d4:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   1801989d9:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   1801989de:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   1801989e5:	00 00 
   1801989e7:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   1801989ec:	41 b8 09 00 00 00    	mov    r8d,0x9
   1801989f2:	48 8d 15 4f 1b 52 00 	lea    rdx,[rip+0x521b4f]        # 0x1806ba548
   1801989f9:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801989fe:	e8 ad 09 e8 ff       	call   0x1800193b0
   180198a03:	90                   	nop
   180198a04:	4c 8d 87 dc 04 00 00 	lea    r8,[rdi+0x4dc]
   180198a0b:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198a10:	48 8b cf             	mov    rcx,rdi
   180198a13:	e8 68 9e 0e 00       	call   0x180282880
   180198a18:	90                   	nop
   180198a19:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198a1e:	48 83 fa 10          	cmp    rdx,0x10
   180198a22:	72 35                	jb     0x180198a59
   180198a24:	48 ff c2             	inc    rdx
   180198a27:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198a2c:	48 8b c1             	mov    rax,rcx
   180198a2f:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198a36:	72 1c                	jb     0x180198a54
   180198a38:	48 83 c2 27          	add    rdx,0x27
   180198a3c:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198a40:	48 2b c1             	sub    rax,rcx
   180198a43:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198a47:	48 83 f8 1f          	cmp    rax,0x1f
   180198a4b:	76 07                	jbe    0x180198a54
   180198a4d:	ff 15 fd 77 4d 00    	call   QWORD PTR [rip+0x4d77fd]        # 0x180670250
   180198a53:	cc                   	int3
   180198a54:	e8 37 5e ec ff       	call   0x18005e890
   180198a59:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198a5e:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198a63:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198a6a:	00 00 
   180198a6c:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198a71:	41 b8 0a 00 00 00    	mov    r8d,0xa
   180198a77:	48 8d 15 da 1a 52 00 	lea    rdx,[rip+0x521ada]        # 0x1806ba558
   180198a7e:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198a83:	e8 28 09 e8 ff       	call   0x1800193b0
   180198a88:	90                   	nop
   180198a89:	4c 8d 87 e0 04 00 00 	lea    r8,[rdi+0x4e0]
   180198a90:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198a95:	48 8b cf             	mov    rcx,rdi
   180198a98:	e8 e3 9d 0e 00       	call   0x180282880
   180198a9d:	90                   	nop
   180198a9e:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198aa3:	48 83 fa 10          	cmp    rdx,0x10
   180198aa7:	72 35                	jb     0x180198ade
   180198aa9:	48 ff c2             	inc    rdx
   180198aac:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198ab1:	48 8b c1             	mov    rax,rcx
   180198ab4:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198abb:	72 1c                	jb     0x180198ad9
   180198abd:	48 83 c2 27          	add    rdx,0x27
   180198ac1:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198ac5:	48 2b c1             	sub    rax,rcx
   180198ac8:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198acc:	48 83 f8 1f          	cmp    rax,0x1f
   180198ad0:	76 07                	jbe    0x180198ad9
   180198ad2:	ff 15 78 77 4d 00    	call   QWORD PTR [rip+0x4d7778]        # 0x180670250
   180198ad8:	cc                   	int3
   180198ad9:	e8 b2 5d ec ff       	call   0x18005e890
   180198ade:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198ae3:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198ae8:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198aef:	00 00 
   180198af1:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198af6:	41 b8 1e 00 00 00    	mov    r8d,0x1e
   180198afc:	48 8d 15 dd 11 4e 00 	lea    rdx,[rip+0x4e11dd]        # 0x180679ce0
   180198b03:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198b08:	e8 a3 08 e8 ff       	call   0x1800193b0
   180198b0d:	90                   	nop
   180198b0e:	4c 8d 87 e4 04 00 00 	lea    r8,[rdi+0x4e4]
   180198b15:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198b1a:	48 8b cf             	mov    rcx,rdi
   180198b1d:	e8 5e 9d 0e 00       	call   0x180282880
   180198b22:	90                   	nop
   180198b23:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198b28:	48 83 fa 10          	cmp    rdx,0x10
   180198b2c:	72 35                	jb     0x180198b63
   180198b2e:	48 ff c2             	inc    rdx
   180198b31:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198b36:	48 8b c1             	mov    rax,rcx
   180198b39:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198b40:	72 1c                	jb     0x180198b5e
   180198b42:	48 83 c2 27          	add    rdx,0x27
   180198b46:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198b4a:	48 2b c1             	sub    rax,rcx
   180198b4d:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198b51:	48 83 f8 1f          	cmp    rax,0x1f
   180198b55:	76 07                	jbe    0x180198b5e
   180198b57:	ff 15 f3 76 4d 00    	call   QWORD PTR [rip+0x4d76f3]        # 0x180670250
   180198b5d:	cc                   	int3
   180198b5e:	e8 2d 5d ec ff       	call   0x18005e890
   180198b63:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198b68:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198b6d:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198b74:	00 00 
   180198b76:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198b7b:	41 b8 10 00 00 00    	mov    r8d,0x10
   180198b81:	48 8d 15 e0 19 52 00 	lea    rdx,[rip+0x5219e0]        # 0x1806ba568
   180198b88:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198b8d:	e8 1e 08 e8 ff       	call   0x1800193b0
   180198b92:	90                   	nop
   180198b93:	4c 8d 87 e8 04 00 00 	lea    r8,[rdi+0x4e8]
   180198b9a:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198b9f:	48 8b cf             	mov    rcx,rdi
   180198ba2:	e8 d9 9c 0e 00       	call   0x180282880
   180198ba7:	90                   	nop
   180198ba8:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198bad:	48 83 fa 10          	cmp    rdx,0x10
   180198bb1:	72 35                	jb     0x180198be8
   180198bb3:	48 ff c2             	inc    rdx
   180198bb6:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198bbb:	48 8b c1             	mov    rax,rcx
   180198bbe:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198bc5:	72 1c                	jb     0x180198be3
   180198bc7:	48 83 c2 27          	add    rdx,0x27
   180198bcb:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198bcf:	48 2b c1             	sub    rax,rcx
   180198bd2:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198bd6:	48 83 f8 1f          	cmp    rax,0x1f
   180198bda:	76 07                	jbe    0x180198be3
   180198bdc:	ff 15 6e 76 4d 00    	call   QWORD PTR [rip+0x4d766e]        # 0x180670250
   180198be2:	cc                   	int3
   180198be3:	e8 a8 5c ec ff       	call   0x18005e890
   180198be8:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198bed:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198bf2:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198bf9:	00 00 
   180198bfb:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198c00:	41 b8 0f 00 00 00    	mov    r8d,0xf
   180198c06:	48 8d 15 73 19 52 00 	lea    rdx,[rip+0x521973]        # 0x1806ba580
   180198c0d:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198c12:	e8 99 07 e8 ff       	call   0x1800193b0
   180198c17:	90                   	nop
   180198c18:	4c 8d 87 ec 04 00 00 	lea    r8,[rdi+0x4ec]
   180198c1f:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198c24:	48 8b cf             	mov    rcx,rdi
   180198c27:	e8 54 9c 0e 00       	call   0x180282880
   180198c2c:	90                   	nop
   180198c2d:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198c32:	48 83 fa 10          	cmp    rdx,0x10
   180198c36:	72 35                	jb     0x180198c6d
   180198c38:	48 ff c2             	inc    rdx
   180198c3b:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198c40:	48 8b c1             	mov    rax,rcx
   180198c43:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198c4a:	72 1c                	jb     0x180198c68
   180198c4c:	48 83 c2 27          	add    rdx,0x27
   180198c50:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198c54:	48 2b c1             	sub    rax,rcx
   180198c57:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198c5b:	48 83 f8 1f          	cmp    rax,0x1f
   180198c5f:	76 07                	jbe    0x180198c68
   180198c61:	ff 15 e9 75 4d 00    	call   QWORD PTR [rip+0x4d75e9]        # 0x180670250
   180198c67:	cc                   	int3
   180198c68:	e8 23 5c ec ff       	call   0x18005e890
   180198c6d:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198c72:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198c77:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198c7e:	00 00 
   180198c80:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198c85:	41 b8 19 00 00 00    	mov    r8d,0x19
   180198c8b:	48 8d 15 fe 18 52 00 	lea    rdx,[rip+0x5218fe]        # 0x1806ba590
   180198c92:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198c97:	e8 14 07 e8 ff       	call   0x1800193b0
   180198c9c:	90                   	nop
   180198c9d:	4c 8d 87 f0 04 00 00 	lea    r8,[rdi+0x4f0]
   180198ca4:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198ca9:	48 8b cf             	mov    rcx,rdi
   180198cac:	e8 cf 9b 0e 00       	call   0x180282880
   180198cb1:	90                   	nop
   180198cb2:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198cb7:	48 83 fa 10          	cmp    rdx,0x10
   180198cbb:	72 35                	jb     0x180198cf2
   180198cbd:	48 ff c2             	inc    rdx
   180198cc0:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198cc5:	48 8b c1             	mov    rax,rcx
   180198cc8:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198ccf:	72 1c                	jb     0x180198ced
   180198cd1:	48 83 c2 27          	add    rdx,0x27
   180198cd5:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198cd9:	48 2b c1             	sub    rax,rcx
   180198cdc:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198ce0:	48 83 f8 1f          	cmp    rax,0x1f
   180198ce4:	76 07                	jbe    0x180198ced
   180198ce6:	ff 15 64 75 4d 00    	call   QWORD PTR [rip+0x4d7564]        # 0x180670250
   180198cec:	cc                   	int3
   180198ced:	e8 9e 5b ec ff       	call   0x18005e890
   180198cf2:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198cf7:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198cfc:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198d03:	00 00 
   180198d05:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198d0a:	41 b8 19 00 00 00    	mov    r8d,0x19
   180198d10:	48 8d 15 99 18 52 00 	lea    rdx,[rip+0x521899]        # 0x1806ba5b0
   180198d17:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198d1c:	e8 8f 06 e8 ff       	call   0x1800193b0
   180198d21:	90                   	nop
   180198d22:	4c 8d 87 f4 04 00 00 	lea    r8,[rdi+0x4f4]
   180198d29:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198d2e:	48 8b cf             	mov    rcx,rdi
   180198d31:	e8 4a 9b 0e 00       	call   0x180282880
   180198d36:	90                   	nop
   180198d37:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198d3c:	48 83 fa 10          	cmp    rdx,0x10
   180198d40:	72 35                	jb     0x180198d77
   180198d42:	48 ff c2             	inc    rdx
   180198d45:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198d4a:	48 8b c1             	mov    rax,rcx
   180198d4d:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198d54:	72 1c                	jb     0x180198d72
   180198d56:	48 83 c2 27          	add    rdx,0x27
   180198d5a:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198d5e:	48 2b c1             	sub    rax,rcx
   180198d61:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198d65:	48 83 f8 1f          	cmp    rax,0x1f
   180198d69:	76 07                	jbe    0x180198d72
   180198d6b:	ff 15 df 74 4d 00    	call   QWORD PTR [rip+0x4d74df]        # 0x180670250
   180198d71:	cc                   	int3
   180198d72:	e8 19 5b ec ff       	call   0x18005e890
   180198d77:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198d7c:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198d81:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198d88:	00 00 
   180198d8a:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198d8f:	41 b8 0e 00 00 00    	mov    r8d,0xe
   180198d95:	48 8d 15 34 18 52 00 	lea    rdx,[rip+0x521834]        # 0x1806ba5d0
   180198d9c:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198da1:	e8 0a 06 e8 ff       	call   0x1800193b0
   180198da6:	90                   	nop
   180198da7:	4c 8d 87 f8 04 00 00 	lea    r8,[rdi+0x4f8]
   180198dae:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198db3:	48 8b cf             	mov    rcx,rdi
   180198db6:	e8 c5 9a 0e 00       	call   0x180282880
   180198dbb:	90                   	nop
   180198dbc:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198dc1:	48 83 fa 10          	cmp    rdx,0x10
   180198dc5:	72 35                	jb     0x180198dfc
   180198dc7:	48 ff c2             	inc    rdx
   180198dca:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198dcf:	48 8b c1             	mov    rax,rcx
   180198dd2:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198dd9:	72 1c                	jb     0x180198df7
   180198ddb:	48 83 c2 27          	add    rdx,0x27
   180198ddf:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198de3:	48 2b c1             	sub    rax,rcx
   180198de6:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198dea:	48 83 f8 1f          	cmp    rax,0x1f
   180198dee:	76 07                	jbe    0x180198df7
   180198df0:	ff 15 5a 74 4d 00    	call   QWORD PTR [rip+0x4d745a]        # 0x180670250
   180198df6:	cc                   	int3
   180198df7:	e8 94 5a ec ff       	call   0x18005e890
   180198dfc:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198e01:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198e06:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198e0d:	00 00 
   180198e0f:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198e14:	41 b8 0d 00 00 00    	mov    r8d,0xd
   180198e1a:	48 8d 15 e7 e2 4f 00 	lea    rdx,[rip+0x4fe2e7]        # 0x180697108
   180198e21:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198e26:	e8 85 05 e8 ff       	call   0x1800193b0
   180198e2b:	90                   	nop
   180198e2c:	4c 8d 87 fc 04 00 00 	lea    r8,[rdi+0x4fc]
   180198e33:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198e38:	48 8b cf             	mov    rcx,rdi
   180198e3b:	e8 f0 99 0e 00       	call   0x180282830
   180198e40:	90                   	nop
   180198e41:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198e46:	48 83 fa 10          	cmp    rdx,0x10
   180198e4a:	72 35                	jb     0x180198e81
   180198e4c:	48 ff c2             	inc    rdx
   180198e4f:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198e54:	48 8b c1             	mov    rax,rcx
   180198e57:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198e5e:	72 1c                	jb     0x180198e7c
   180198e60:	48 83 c2 27          	add    rdx,0x27
   180198e64:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198e68:	48 2b c1             	sub    rax,rcx
   180198e6b:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198e6f:	48 83 f8 1f          	cmp    rax,0x1f
   180198e73:	76 07                	jbe    0x180198e7c
   180198e75:	ff 15 d5 73 4d 00    	call   QWORD PTR [rip+0x4d73d5]        # 0x180670250
   180198e7b:	cc                   	int3
   180198e7c:	e8 0f 5a ec ff       	call   0x18005e890
   180198e81:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198e86:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198e8b:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198e92:	00 00 
   180198e94:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198e99:	41 b8 0e 00 00 00    	mov    r8d,0xe
   180198e9f:	48 8d 15 42 99 4e 00 	lea    rdx,[rip+0x4e9942]        # 0x1806827e8
   180198ea6:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198eab:	e8 00 05 e8 ff       	call   0x1800193b0
   180198eb0:	90                   	nop
   180198eb1:	4c 8d 87 04 05 00 00 	lea    r8,[rdi+0x504]
   180198eb8:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198ebd:	48 8b cf             	mov    rcx,rdi
   180198ec0:	e8 bb 99 0e 00       	call   0x180282880
   180198ec5:	90                   	nop
   180198ec6:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198ecb:	48 83 fa 10          	cmp    rdx,0x10
   180198ecf:	72 35                	jb     0x180198f06
   180198ed1:	48 ff c2             	inc    rdx
   180198ed4:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198ed9:	48 8b c1             	mov    rax,rcx
   180198edc:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198ee3:	72 1c                	jb     0x180198f01
   180198ee5:	48 83 c2 27          	add    rdx,0x27
   180198ee9:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198eed:	48 2b c1             	sub    rax,rcx
   180198ef0:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198ef4:	48 83 f8 1f          	cmp    rax,0x1f
   180198ef8:	76 07                	jbe    0x180198f01
   180198efa:	ff 15 50 73 4d 00    	call   QWORD PTR [rip+0x4d7350]        # 0x180670250
   180198f00:	cc                   	int3
   180198f01:	e8 8a 59 ec ff       	call   0x18005e890
   180198f06:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198f0b:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198f10:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198f17:	00 00 
   180198f19:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198f1e:	41 b8 0c 00 00 00    	mov    r8d,0xc
   180198f24:	48 8d 15 b5 16 52 00 	lea    rdx,[rip+0x5216b5]        # 0x1806ba5e0
   180198f2b:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198f30:	e8 7b 04 e8 ff       	call   0x1800193b0
   180198f35:	90                   	nop
   180198f36:	4c 8d 87 08 05 00 00 	lea    r8,[rdi+0x508]
   180198f3d:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198f42:	48 8b cf             	mov    rcx,rdi
   180198f45:	e8 36 99 0e 00       	call   0x180282880
   180198f4a:	90                   	nop
   180198f4b:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198f50:	48 83 fa 10          	cmp    rdx,0x10
   180198f54:	72 35                	jb     0x180198f8b
   180198f56:	48 ff c2             	inc    rdx
   180198f59:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198f5e:	48 8b c1             	mov    rax,rcx
   180198f61:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198f68:	72 1c                	jb     0x180198f86
   180198f6a:	48 83 c2 27          	add    rdx,0x27
   180198f6e:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198f72:	48 2b c1             	sub    rax,rcx
   180198f75:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198f79:	48 83 f8 1f          	cmp    rax,0x1f
   180198f7d:	76 07                	jbe    0x180198f86
   180198f7f:	ff 15 cb 72 4d 00    	call   QWORD PTR [rip+0x4d72cb]        # 0x180670250
   180198f85:	cc                   	int3
   180198f86:	e8 05 59 ec ff       	call   0x18005e890
   180198f8b:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180198f90:	48 89 5c 24 48       	mov    QWORD PTR [rsp+0x48],rbx
   180198f95:	48 c7 44 24 50 0f 00 	mov    QWORD PTR [rsp+0x50],0xf
   180198f9c:	00 00 
   180198f9e:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180198fa3:	41 b8 12 00 00 00    	mov    r8d,0x12
   180198fa9:	48 8d 15 40 16 52 00 	lea    rdx,[rip+0x521640]        # 0x1806ba5f0
   180198fb0:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180198fb5:	e8 f6 03 e8 ff       	call   0x1800193b0
   180198fba:	90                   	nop
   180198fbb:	4c 8d 87 0c 05 00 00 	lea    r8,[rdi+0x50c]
   180198fc2:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180198fc7:	48 8b cf             	mov    rcx,rdi
   180198fca:	e8 b1 98 0e 00       	call   0x180282880
   180198fcf:	90                   	nop
   180198fd0:	48 8b 54 24 50       	mov    rdx,QWORD PTR [rsp+0x50]
   180198fd5:	48 83 fa 10          	cmp    rdx,0x10
   180198fd9:	72 35                	jb     0x180199010
   180198fdb:	48 ff c2             	inc    rdx
   180198fde:	48 8b 4c 24 38       	mov    rcx,QWORD PTR [rsp+0x38]
   180198fe3:	48 8b c1             	mov    rax,rcx
   180198fe6:	48 81 fa 00 10 00 00 	cmp    rdx,0x1000
   180198fed:	72 1c                	jb     0x18019900b
   180198fef:	48 83 c2 27          	add    rdx,0x27
   180198ff3:	48 8b 49 f8          	mov    rcx,QWORD PTR [rcx-0x8]
   180198ff7:	48 2b c1             	sub    rax,rcx
   180198ffa:	48 83 c0 f8          	add    rax,0xfffffffffffffff8
   180198ffe:	48 83 f8 1f          	cmp    rax,0x1f
   180199002:	76 07                	jbe    0x18019900b
   180199004:	ff 15 46 72 4d 00    	call   QWORD PTR [rip+0x4d7246]        # 0x180670250
   18019900a:	cc                   	int3
   18019900b:	e8 80 58 ec ff       	call   0x18005e890
   180199010:	48 89 5c 24 38       	mov    QWORD PTR [rsp+0x38],rbx
   180199015:	66 0f 6f 05 43 fa 4d 	movdqa xmm0,XMMWORD PTR [rip+0x4dfa43]        # 0x180678a60
   18019901c:	00 
   18019901d:	f3 0f 7f 44 24 48    	movdqu XMMWORD PTR [rsp+0x48],xmm0
   180199023:	c6 44 24 38 00       	mov    BYTE PTR [rsp+0x38],0x0
   180199028:	48 8d 15 d9 15 52 00 	lea    rdx,[rip+0x5215d9]        # 0x1806ba608
   18019902f:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199034:	e8 57 eb e7 ff       	call   0x180017b90
   180199039:	90                   	nop
   18019903a:	4c 8d 87 00 05 00 00 	lea    r8,[rdi+0x500]
   180199041:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180199046:	48 8b cf             	mov    rcx,rdi
   180199049:	e8 32 98 0e 00       	call   0x180282880
   18019904e:	90                   	nop
   18019904f:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199054:	e8 67 ea e7 ff       	call   0x180017ac0
   180199059:	48 8d 15 c8 15 52 00 	lea    rdx,[rip+0x5215c8]        # 0x1806ba628
   180199060:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199065:	e8 b6 e6 e7 ff       	call   0x180017720
   18019906a:	90                   	nop
   18019906b:	4c 8d 87 10 05 00 00 	lea    r8,[rdi+0x510]
   180199072:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   180199077:	48 8b cf             	mov    rcx,rdi
   18019907a:	e8 01 98 0e 00       	call   0x180282880
   18019907f:	90                   	nop
   180199080:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199085:	e8 36 ea e7 ff       	call   0x180017ac0
   18019908a:	48 8d 15 b7 15 52 00 	lea    rdx,[rip+0x5215b7]        # 0x1806ba648
   180199091:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199096:	e8 85 e6 e7 ff       	call   0x180017720
   18019909b:	90                   	nop
   18019909c:	4c 8d 87 14 05 00 00 	lea    r8,[rdi+0x514]
   1801990a3:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801990a8:	48 8b cf             	mov    rcx,rdi
   1801990ab:	e8 d0 97 0e 00       	call   0x180282880
   1801990b0:	90                   	nop
   1801990b1:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801990b6:	e8 05 ea e7 ff       	call   0x180017ac0
   1801990bb:	48 8d 15 9e 15 52 00 	lea    rdx,[rip+0x52159e]        # 0x1806ba660
   1801990c2:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801990c7:	e8 54 e6 e7 ff       	call   0x180017720
   1801990cc:	90                   	nop
   1801990cd:	4c 8d 87 18 05 00 00 	lea    r8,[rdi+0x518]
   1801990d4:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801990d9:	48 8b cf             	mov    rcx,rdi
   1801990dc:	e8 9f 97 0e 00       	call   0x180282880
   1801990e1:	90                   	nop
   1801990e2:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801990e7:	e8 d4 e9 e7 ff       	call   0x180017ac0
   1801990ec:	48 8d 15 85 15 52 00 	lea    rdx,[rip+0x521585]        # 0x1806ba678
   1801990f3:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801990f8:	e8 23 e6 e7 ff       	call   0x180017720
   1801990fd:	90                   	nop
   1801990fe:	4c 8d 87 20 05 00 00 	lea    r8,[rdi+0x520]
   180199105:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019910a:	48 8b cf             	mov    rcx,rdi
   18019910d:	e8 6e 97 0e 00       	call   0x180282880
   180199112:	90                   	nop
   180199113:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199118:	e8 a3 e9 e7 ff       	call   0x180017ac0
   18019911d:	48 8d 15 6c 15 52 00 	lea    rdx,[rip+0x52156c]        # 0x1806ba690
   180199124:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199129:	e8 f2 e5 e7 ff       	call   0x180017720
   18019912e:	90                   	nop
   18019912f:	4c 8d 87 24 05 00 00 	lea    r8,[rdi+0x524]
   180199136:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019913b:	48 8b cf             	mov    rcx,rdi
   18019913e:	e8 3d 97 0e 00       	call   0x180282880
   180199143:	90                   	nop
   180199144:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   180199149:	e8 72 e9 e7 ff       	call   0x180017ac0
   18019914e:	48 8d 15 5b 15 52 00 	lea    rdx,[rip+0x52155b]        # 0x1806ba6b0
   180199155:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   18019915a:	e8 c1 e5 e7 ff       	call   0x180017720
   18019915f:	90                   	nop
   180199160:	4c 8d 87 28 05 00 00 	lea    r8,[rdi+0x528]
   180199167:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019916c:	48 8b cf             	mov    rcx,rdi
   18019916f:	e8 0c 97 0e 00       	call   0x180282880
   180199174:	90                   	nop
   180199175:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   18019917a:	e8 41 e9 e7 ff       	call   0x180017ac0
   18019917f:	48 8d 15 52 15 52 00 	lea    rdx,[rip+0x521552]        # 0x1806ba6d8
   180199186:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   18019918b:	e8 90 e5 e7 ff       	call   0x180017720
   180199190:	90                   	nop
   180199191:	4c 8d 87 2c 05 00 00 	lea    r8,[rdi+0x52c]
   180199198:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   18019919d:	48 8b cf             	mov    rcx,rdi
   1801991a0:	e8 db 96 0e 00       	call   0x180282880
   1801991a5:	90                   	nop
   1801991a6:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801991ab:	e8 10 e9 e7 ff       	call   0x180017ac0
   1801991b0:	48 8d 15 41 15 52 00 	lea    rdx,[rip+0x521541]        # 0x1806ba6f8
   1801991b7:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801991bc:	e8 5f e5 e7 ff       	call   0x180017720
   1801991c1:	90                   	nop
   1801991c2:	4c 8d 87 30 05 00 00 	lea    r8,[rdi+0x530]
   1801991c9:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801991ce:	48 8b cf             	mov    rcx,rdi
   1801991d1:	e8 aa 96 0e 00       	call   0x180282880
   1801991d6:	90                   	nop
   1801991d7:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801991dc:	e8 df e8 e7 ff       	call   0x180017ac0
   1801991e1:	48 8d 15 30 15 52 00 	lea    rdx,[rip+0x521530]        # 0x1806ba718
   1801991e8:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   1801991ed:	e8 2e e5 e7 ff       	call   0x180017720
   1801991f2:	90                   	nop
   1801991f3:	4c 8d 87 34 05 00 00 	lea    r8,[rdi+0x534]
   1801991fa:	48 8d 54 24 38       	lea    rdx,[rsp+0x38]
   1801991ff:	48 8b cf             	mov    rcx,rdi
   180199202:	e8 79 96 0e 00       	call   0x180282880
   180199207:	90                   	nop
   180199208:	48 8d 4c 24 38       	lea    rcx,[rsp+0x38]
   18019920d:	e8 ae e8 e7 ff       	call   0x180017ac0
   180199212:	48 8d 15 1f 15 52 00 	lea    rdx,[rip+0x52151f]        # 0x1806ba738
   180199219:	48 8d 4c 24 58       	lea    rcx,[rsp+0x58]
   18019921e:	e8 fd e4 e7 ff       	call   0x180017720
   180199223:	90                   	nop
   180199224:	4c 8d 87 44 05 00 00 	lea    r8,[rdi+0x544]
   18019922b:	48 8d 54 24 58       	lea    rdx,[rsp+0x58]
   180199230:	48 8b cf             	mov    rcx,rdi
   180199233:	e8 48 96 0e 00       	call   0x180282880
   180199238:	90                   	nop
   180199239:	48 8d 4c 24 58       	lea    rcx,[rsp+0x58]
   18019923e:	e8 7d e8 e7 ff       	call   0x180017ac0
   180199243:	48 8d 15 fe 14 52 00 	lea    rdx,[rip+0x5214fe]        # 0x1806ba748
   18019924a:	48 8d 4c 24 78       	lea    rcx,[rsp+0x78]
   18019924f:	e8 cc e4 e7 ff       	call   0x180017720
   180199254:	90                   	nop
   180199255:	4c 8d 87 48 05 00 00 	lea    r8,[rdi+0x548]
   18019925c:	48 8d 54 24 78       	lea    rdx,[rsp+0x78]
   180199261:	48 8b cf             	mov    rcx,rdi
   180199264:	e8 17 96 0e 00       	call   0x180282880
   180199269:	90                   	nop
   18019926a:	48 8d 4c 24 78       	lea    rcx,[rsp+0x78]
   18019926f:	e8 4c e8 e7 ff       	call   0x180017ac0
   180199274:	48 8d 15 e5 14 52 00 	lea    rdx,[rip+0x5214e5]        # 0x1806ba760
   18019927b:	48 8d 4d 98          	lea    rcx,[rbp-0x68]
   18019927f:	e8 9c e4 e7 ff       	call   0x180017720
   180199284:	90                   	nop
   180199285:	4c 8d 87 1c 05 00 00 	lea    r8,[rdi+0x51c]
   18019928c:	48 8d 55 98          	lea    rdx,[rbp-0x68]
   180199290:	48 8b cf             	mov    rcx,rdi
   180199293:	e8 e8 95 0e 00       	call   0x180282880
   180199298:	90                   	nop
   180199299:	48 8d 4d 98          	lea    rcx,[rbp-0x68]
   18019929d:	e8 1e e8 e7 ff       	call   0x180017ac0
   1801992a2:	48 8d 15 cf 14 52 00 	lea    rdx,[rip+0x5214cf]        # 0x1806ba778
   1801992a9:	48 8d 4d b8          	lea    rcx,[rbp-0x48]
   1801992ad:	e8 6e e4 e7 ff       	call   0x180017720
   1801992b2:	90                   	nop
   1801992b3:	4c 8d 87 38 05 00 00 	lea    r8,[rdi+0x538]
   1801992ba:	48 8d 55 b8          	lea    rdx,[rbp-0x48]
   1801992be:	48 8b cf             	mov    rcx,rdi
   1801992c1:	e8 ba 95 0e 00       	call   0x180282880
   1801992c6:	90                   	nop
   1801992c7:	48 8d 4d b8          	lea    rcx,[rbp-0x48]
   1801992cb:	e8 f0 e7 e7 ff       	call   0x180017ac0
   1801992d0:	48 8d 15 19 de 4f 00 	lea    rdx,[rip+0x4fde19]        # 0x1806970f0
   1801992d7:	48 8d 4d d8          	lea    rcx,[rbp-0x28]
   1801992db:	e8 40 e4 e7 ff       	call   0x180017720
   1801992e0:	90                   	nop
   1801992e1:	4c 8d 87 3c 05 00 00 	lea    r8,[rdi+0x53c]
   1801992e8:	48 8d 55 d8          	lea    rdx,[rbp-0x28]
   1801992ec:	48 8b cf             	mov    rcx,rdi
   1801992ef:	e8 8c 95 0e 00       	call   0x180282880
   1801992f4:	90                   	nop
   1801992f5:	48 8d 4d d8          	lea    rcx,[rbp-0x28]
   1801992f9:	e8 c2 e7 e7 ff       	call   0x180017ac0
   1801992fe:	48 8d 15 f3 1f 51 00 	lea    rdx,[rip+0x511ff3]        # 0x1806ab2f8
   180199305:	48 8d 4d f8          	lea    rcx,[rbp-0x8]
   180199309:	e8 12 e4 e7 ff       	call   0x180017720
   18019930e:	90                   	nop
   18019930f:	4c 8d 87 40 05 00 00 	lea    r8,[rdi+0x540]
   180199316:	48 8d 55 f8          	lea    rdx,[rbp-0x8]
   18019931a:	48 8b cf             	mov    rcx,rdi
   18019931d:	e8 5e 95 0e 00       	call   0x180282880
   180199322:	90                   	nop
   180199323:	48 8d 4d f8          	lea    rcx,[rbp-0x8]
   180199327:	e8 94 e7 e7 ff       	call   0x180017ac0
   18019932c:	48 8d 15 65 14 52 00 	lea    rdx,[rip+0x521465]        # 0x1806ba798
   180199333:	48 8d 4d 18          	lea    rcx,[rbp+0x18]
   180199337:	e8 e4 e3 e7 ff       	call   0x180017720
   18019933c:	90                   	nop
   18019933d:	4c 8d 87 50 05 00 00 	lea    r8,[rdi+0x550]
   180199344:	48 8d 55 18          	lea    rdx,[rbp+0x18]
   180199348:	48 8b cf             	mov    rcx,rdi
   18019934b:	e8 30 95 0e 00       	call   0x180282880
   180199350:	90                   	nop
   180199351:	48 8d 4d 18          	lea    rcx,[rbp+0x18]
   180199355:	e8 66 e7 e7 ff       	call   0x180017ac0
   18019935a:	48 8d 15 47 14 52 00 	lea    rdx,[rip+0x521447]        # 0x1806ba7a8
   180199361:	48 8d 4d 38          	lea    rcx,[rbp+0x38]
   180199365:	e8 b6 e3 e7 ff       	call   0x180017720
   18019936a:	90                   	nop
   18019936b:	4c 8d 87 4c 05 00 00 	lea    r8,[rdi+0x54c]
   180199372:	48 8d 55 38          	lea    rdx,[rbp+0x38]
   180199376:	48 8b cf             	mov    rcx,rdi
   180199379:	e8 02 95 0e 00       	call   0x180282880
   18019937e:	90                   	nop
   18019937f:	48 8d 4d 38          	lea    rcx,[rbp+0x38]
   180199383:	e8 38 e7 e7 ff       	call   0x180017ac0
   180199388:	48 8d 15 31 14 52 00 	lea    rdx,[rip+0x521431]        # 0x1806ba7c0
   18019938f:	48 8d 4d 58          	lea    rcx,[rbp+0x58]
   180199393:	e8 88 e3 e7 ff       	call   0x180017720
   180199398:	90                   	nop
   180199399:	4c 8d 87 54 05 00 00 	lea    r8,[rdi+0x554]
   1801993a0:	48 8d 55 58          	lea    rdx,[rbp+0x58]
   1801993a4:	48 8b cf             	mov    rcx,rdi
   1801993a7:	e8 84 94 0e 00       	call   0x180282830
   1801993ac:	90                   	nop
   1801993ad:	48 8d 4d 58          	lea    rcx,[rbp+0x58]
   1801993b1:	e8 0a e7 e7 ff       	call   0x180017ac0
   1801993b6:	48 8d 15 13 14 52 00 	lea    rdx,[rip+0x521413]        # 0x1806ba7d0
   1801993bd:	48 8d 4d 78          	lea    rcx,[rbp+0x78]
   1801993c1:	e8 5a e3 e7 ff       	call   0x180017720
   1801993c6:	90                   	nop
   1801993c7:	4c 8d 87 58 05 00 00 	lea    r8,[rdi+0x558]
   1801993ce:	48 8d 55 78          	lea    rdx,[rbp+0x78]
   1801993d2:	48 8b cf             	mov    rcx,rdi
   1801993d5:	e8 56 94 0e 00       	call   0x180282830
   1801993da:	90                   	nop
   1801993db:	48 8d 4d 78          	lea    rcx,[rbp+0x78]
   1801993df:	e8 dc e6 e7 ff       	call   0x180017ac0
   1801993e4:	48 8d 15 f5 13 52 00 	lea    rdx,[rip+0x5213f5]        # 0x1806ba7e0
   1801993eb:	48 8d 8d 98 00 00 00 	lea    rcx,[rbp+0x98]
   1801993f2:	e8 29 e3 e7 ff       	call   0x180017720
   1801993f7:	90                   	nop
   1801993f8:	4c 8d 87 5c 05 00 00 	lea    r8,[rdi+0x55c]
   1801993ff:	48 8d 95 98 00 00 00 	lea    rdx,[rbp+0x98]
   180199406:	48 8b cf             	mov    rcx,rdi
   180199409:	e8 22 94 0e 00       	call   0x180282830
   18019940e:	90                   	nop
   18019940f:	48 8d 8d 98 00 00 00 	lea    rcx,[rbp+0x98]
   180199416:	e8 a5 e6 e7 ff       	call   0x180017ac0
   18019941b:	48 8d 15 d6 13 52 00 	lea    rdx,[rip+0x5213d6]        # 0x1806ba7f8
   180199422:	48 8d 8d b8 00 00 00 	lea    rcx,[rbp+0xb8]
   180199429:	e8 f2 e2 e7 ff       	call   0x180017720
   18019942e:	90                   	nop
   18019942f:	4c 8d 87 60 05 00 00 	lea    r8,[rdi+0x560]
   180199436:	48 8d 95 b8 00 00 00 	lea    rdx,[rbp+0xb8]
   18019943d:	48 8b cf             	mov    rcx,rdi
   180199440:	e8 eb 93 0e 00       	call   0x180282830
   180199445:	90                   	nop
   180199446:	48 8d 8d b8 00 00 00 	lea    rcx,[rbp+0xb8]
   18019944d:	e8 6e e6 e7 ff       	call   0x180017ac0
   180199452:	48 8d 15 b7 13 52 00 	lea    rdx,[rip+0x5213b7]        # 0x1806ba810
   180199459:	48 8d 8d d8 00 00 00 	lea    rcx,[rbp+0xd8]
   180199460:	e8 bb e2 e7 ff       	call   0x180017720
   180199465:	90                   	nop
   180199466:	4c 8d 87 68 05 00 00 	lea    r8,[rdi+0x568]
   18019946d:	48 8d 95 d8 00 00 00 	lea    rdx,[rbp+0xd8]
   180199474:	48 8b cf             	mov    rcx,rdi
   180199477:	e8 b4 93 0e 00       	call   0x180282830
   18019947c:	90                   	nop
   18019947d:	48 8d 8d d8 00 00 00 	lea    rcx,[rbp+0xd8]
   180199484:	e8 37 e6 e7 ff       	call   0x180017ac0
   180199489:	48 8d 15 90 13 52 00 	lea    rdx,[rip+0x521390]        # 0x1806ba820
   180199490:	48 8d 8d f8 00 00 00 	lea    rcx,[rbp+0xf8]
   180199497:	e8 84 e2 e7 ff       	call   0x180017720
   18019949c:	90                   	nop
   18019949d:	4c 8d 87 6c 05 00 00 	lea    r8,[rdi+0x56c]
   1801994a4:	48 8d 95 f8 00 00 00 	lea    rdx,[rbp+0xf8]
   1801994ab:	48 8b cf             	mov    rcx,rdi
   1801994ae:	e8 7d 93 0e 00       	call   0x180282830
   1801994b3:	90                   	nop
   1801994b4:	48 8d 8d f8 00 00 00 	lea    rcx,[rbp+0xf8]
   1801994bb:	e8 00 e6 e7 ff       	call   0x180017ac0
   1801994c0:	48 8d 15 69 13 52 00 	lea    rdx,[rip+0x521369]        # 0x1806ba830
   1801994c7:	48 8d 8d 18 01 00 00 	lea    rcx,[rbp+0x118]
   1801994ce:	e8 4d e2 e7 ff       	call   0x180017720
   1801994d3:	90                   	nop
   1801994d4:	4c 8d 87 70 05 00 00 	lea    r8,[rdi+0x570]
   1801994db:	48 8d 95 18 01 00 00 	lea    rdx,[rbp+0x118]
   1801994e2:	48 8b cf             	mov    rcx,rdi
   1801994e5:	e8 46 93 0e 00       	call   0x180282830
   1801994ea:	90                   	nop
   1801994eb:	48 8d 8d 18 01 00 00 	lea    rcx,[rbp+0x118]
   1801994f2:	e8 c9 e5 e7 ff       	call   0x180017ac0
   1801994f7:	90                   	nop
   1801994f8:	48 8b c7             	mov    rax,rdi
   1801994fb:	48 8b 8d 38 01 00 00 	mov    rcx,QWORD PTR [rbp+0x138]
   180199502:	48 33 cc             	xor    rcx,rsp
   180199505:	e8 96 27 4b 00       	call   0x18064bca0
   18019950a:	4c 8d 9c 24 40 02 00 	lea    r11,[rsp+0x240]
   180199511:	00 
   180199512:	49 8b 5b 38          	mov    rbx,QWORD PTR [r11+0x38]
   180199516:	49 8b 73 40          	mov    rsi,QWORD PTR [r11+0x40]
   18019951a:	49 8b 7b 48          	mov    rdi,QWORD PTR [r11+0x48]
   18019951e:	49 8b e3             	mov    rsp,r11
   180199521:	41 5f                	pop    r15
   180199523:	41 5e                	pop    r14
   180199525:	41 5d                	pop    r13
   180199527:	41 5c                	pop    r12
   180199529:	5d                   	pop    rbp
   18019952a:	c3                   	ret
