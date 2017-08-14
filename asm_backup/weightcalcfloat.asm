format PE64
;use64

include 'win64ax.inc'

s0=28*28
s1=104
s2=10

section '.text' code readable executable
sub rsp,8 ;align stack to multiple of 16

macro loaddata{

stmxcsr dword [temp]
mov eax,dword [temp]
or eax, 0x8040	;flush to zero and zero denormal numbers
mov dword [temp],eax
ldmxcsr dword [temp]

invoke CreateFile, f1n,GENERIC_READ,FILE_SHARE_WRITE,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
mov [f1],rax
invoke GetFileSize,[f1],0
mov [f1s],rax
invoke VirtualAlloc, 0,[f1s],MEM_COMMIT+MEM_RESERVE,0x04
mov [dattemp],rax
invoke ReadFile, [f1],[dattemp],[f1s],temp,0
invoke CloseHandle,[f1]

invoke CreateFile, f2n,GENERIC_READ,FILE_SHARE_WRITE,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
mov [f2],rax
invoke GetFileSize,[f2],0
mov [f2s],rax
invoke VirtualAlloc, 0,[f2s],MEM_COMMIT+MEM_RESERVE,0x04
mov [labelstemp],rax
invoke ReadFile, [f2],[labelstemp],[f2s],temp,0
invoke CloseHandle,[f2]

;align labels data to a new array
invoke VirtualAlloc, 0,[f2s],MEM_COMMIT+MEM_RESERVE,0x04
mov [labels],rax
mov rdi,[labels]
mov rsi,[labelstemp]
add rsi,8
mov rcx,[f2s]
sub rcx,8
mov [picnum], rcx
rep movsb
invoke VirtualFree,[labelstemp],0,MEM_RELEASE

;load bytes range 0-255 to doubles range 0-1 to dat
mov rax,[picnum]
imul rax, s0*4
invoke VirtualAlloc, 0,rax,MEM_COMMIT+MEM_RESERVE,0x04
mov [dat],rax
mov rsi,[dattemp]
add rsi,16
mov rdi,[dat]
mov rbx,[picnum]
imul rbx,s0
fild qword [maxintensity]
xor rax,rax
mov [temp],rax
@@: mov al,[rsi]
mov byte [temp],al
fild word [temp]
fdiv st0,st1
fstp dword [rdi]
inc rsi
add rdi,4
dec rbx
ja @b
finit
invoke VirtualFree,[dattemp],0,MEM_RELEASE
}

macro allocweights{
invoke VirtualAlloc, 0,s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [v1],rax
invoke VirtualAlloc, 0,(s2+7)*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [v2],rax
invoke VirtualAlloc, 0,s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [b1],rax
invoke VirtualAlloc, 0,(s2+7)*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [b2],rax
invoke VirtualAlloc, 0,s1*s0*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [w1],rax
invoke VirtualAlloc, 0,s2*s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [w2],rax
invoke VirtualAlloc, 0,s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gb1],rax
invoke VirtualAlloc, 0,s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gsb1],rax
invoke VirtualAlloc, 0,(s2+7)*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gb2],rax
invoke VirtualAlloc, 0,(s2+7)*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gsb2],rax
invoke VirtualAlloc, 0,s1*s0*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gw1],rax
invoke VirtualAlloc, 0,s1*s0*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gsw1],rax
invoke VirtualAlloc, 0,s2*s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gw2],rax
invoke VirtualAlloc, 0,s2*s1*4,MEM_COMMIT+MEM_RESERVE,0x04
mov [gsw2],rax
}

;MACROS{{{{{{{{{{{{{{{{{{{

macro randomizeweights{  ;random rbx doubles gaussian, std 1, mean 0 to rdi
      local rand
finit
rand:
invoke rand_s,temp
invoke rand_s,temp+4
and byte [temp+7],0x7f
fild qword [powtwo]
fild qword [temp]
fscale
fxch st1
invoke rand_s,temp
invoke rand_s,temp+4
and byte [temp+7],0x7f
fild qword [temp]
fscale
fxch
fstp st0;now two uniform random variables in st0 and st1
fld1
fadd st0,st0
fchs
fld st1
fyl2x
fldl2e
fdivp st1,st0
fsqrt
fldpi
fadd st0,st0
fmul st0,st3
fld st0 ;2pix2,2pix2,sqrt(-ln(2x1),x1,x2
fcos
fmul st0,st2
fstp dword [rdi]
add rdi,4
dec rbx
jz @f
fsin
fmulp st1,st0
fstp dword [rdi]
fstp st0
fstp st0
add rdi,4
dec rbx
jz @f
jmp rand
@@:
}

;normalize weights
macro normalize{
fild qword [ws1]
fld qword [ws1d]
fmulp st1,st0
fsqrt
mov rcx,s0*s1
mov rdi,[w1]
@@:fld dword [rdi]
fdiv st0,st1
fstp dword [rdi]
add rdi,4
dec rcx
jnz @b
mov rcx,s1
mov rdi,[b1]
@@:fld dword [rdi]
fdiv st0,st1
fstp dword [rdi]
add rdi,4
dec rcx
jnz @b
fstp st0

fild qword [ws2]
fsqrt
mov rcx,s1*s2
mov rdi,[w2]
@@:fld dword [rdi]
fdiv st0,st1
fstp dword [rdi]
add rdi,4
dec rcx
ja @b
mov rcx,s2
mov rdi,[b2]
@@:fld dword [rdi]
fdiv st0,st1
fstp dword [rdi]
add rdi,4
dec rcx
ja @b
fstp st0
}


;random to rdx, offset to r13, curLabel to rbp
macro randompic{
invoke rand_s,temp
mov eax,dword [temp]
xor rdx,rdx
mov rbx,[picnum]
div ebx
mov r13d,edx
imul r13,s0*4
mov rbp,[labels]
movzx rbp,byte[rbp+rdx]
}

;feedforward
macro feedf{
;from first layer to the second, curOffset is in r13
      local feed1, feed2
mov rax,[w1]
mov rdi,[v1]
mov rdx,[b1]
mov rbx,s1
mov r8,[dat]
add r8,r13
vxorps ymm4,ymm4,ymm4
feed1: vxorps ymm2,ymm2,ymm2
vmovss xmm5,[rdx]
mov rsi,r8
mov rcx, s0/8
@@:
vmovaps ymm0,[rsi]
vmovaps ymm6,[rax]
vmulps ymm1,ymm0,ymm6
vaddps ymm2,ymm2,ymm1
add rsi,4*8
add rax,4*8
dec rcx
ja @b
vhaddps ymm2,ymm2,ymm2
vhaddps ymm2,ymm2,ymm2
vperm2f128 ymm3,ymm2,ymm2,0x11
vaddps ymm2,ymm2,ymm3
vaddps ymm2,ymm2,ymm5
vcmpps ymm5,ymm2,ymm4,110b
vandps ymm2,ymm2,ymm5
vmovss [rdi],xmm2
add rdi,4
add rdx,4
dec rbx
ja feed1
;from second to the third
mov rax,[w2]
mov rdi,[v2]
mov rdx,[b2]
mov rbx,s2
mov r8,[v1]
feed2: vxorps ymm2,ymm2,ymm2
vmovss xmm5,[rdx]
mov rsi,r8
mov rcx, s1/8
@@:
vmovaps ymm0,[rsi]
vmovaps ymm6,[rax]
vmulps ymm1,ymm0,ymm6
vaddps ymm2,ymm2,ymm1
add rsi,4*8
add rax,4*8
dec rcx
ja @b
vhaddps ymm2,ymm2,ymm2
vhaddps ymm2,ymm2,ymm2
vperm2f128 ymm3,ymm2,ymm2,0x11
vaddps ymm2,ymm2,ymm3
vaddps ymm2,ymm2,ymm5
vcmpps ymm5,ymm2,ymm4,110b
vandps ymm2,ymm2,ymm5
vmovss [rdi],xmm2
add rdi,4
add rdx,4
dec rbx
ja feed2
}

;backpropagation
macro backprop{
local gw1loop, gw2loop
;sub 1 from curLabel v2
mov rax,[v2]
vmovss xmm0,[rax+4*rbp]
vmovss xmm1, dword [one]
vsubss xmm0,xmm0,xmm1
vmovss [rax+4*rbp],xmm0

;calc gb2
mov rbx,[gb2]
mov rcx,(s2+7)/8
@@: vmovaps ymm0,[rax]
vmovaps [rbx],ymm0
add rbx,4*8
add rax,4*8
dec rcx
ja @b

;add 1 to curLabel v2
mov rax,[v2]
vmovss xmm0,[rax+4*rbp]
vmovss xmm1, dword [one]
vaddss xmm0,xmm0,xmm1
vmovss [rax+4*rbp],xmm0

;finish gb2, zero where v2 is zero
mov rax,[v2]
mov rbx,[gb2]
mov rcx, (s2+7)/8
vxorps ymm0,ymm0,ymm0
@@: vmovaps ymm1,[rax]
vcmpps ymm1,ymm1,ymm0,110b
vmovaps ymm2,[rbx]
vandps ymm2,ymm2,ymm1
vmovaps [rbx],ymm2
add rax,4*8
add rbx,4*8
dec rcx
ja @b

;zero gb1 register
vxorps ymm0,ymm0,ymm0
mov rcx,s1/8
mov rax,[gb1]
@@: vmovaps [rax],ymm0
add rax,4*8
dec rcx
ja @b

;calc gw2 and gb1
mov r8,s2
mov rax,[gb2]
mov r9,[gw2]
mov r10,[w2]
gw2loop:
vbroadcastss ymm0,[rax]
mov rdx,[v1]
mov rbx,[gb1]
mov rcx,s1/8
@@: vmovaps ymm1,[rdx]
vmovaps ymm3,[r10]
vmovaps ymm4,[rbx]
vmulps ymm2,ymm1,ymm0
vmulps ymm5,ymm3,ymm0
vaddps ymm4,ymm4,ymm5
vmovaps [rbx],ymm4
vmovaps [r9],ymm2
add rdx,4*8
add rbx,4*8
add r9,4*8
add r10,4*8
dec rcx
ja @b
add rax,4
dec r8
ja gw2loop

;finish calculating gb1, zero where v1 is zero
mov rbx,[v1]
mov rax,[gb1]
mov rcx,s1/8
vxorps ymm0,ymm0,ymm0
@@: vmovaps ymm1,[rbx]
vcmpps ymm2,ymm1,ymm0,110b
vmovaps ymm3,[rax]
vandps ymm3,ymm3,ymm2
vmovaps [rax],ymm3
add rbx,8*4
add rax,8*4
dec rcx
ja @b

;calculate gw1
mov rbx,[gb1]
mov rdx,[gw1]
mov rax,[dat]
add rax,r13
mov r9,s1
gw1loop: vbroadcastss ymm0,[rbx]
mov r8,rax
mov rcx,s0/8
@@: vmovaps ymm1,[r8]
vmulps ymm1,ymm1,ymm0
vmovaps [rdx],ymm1
add rdx,4*8
add r8,4*8
dec rcx
ja @b
add rbx,8
dec r9
ja gw1loop
}

macro movestuff{
@@: vmovaps ymm0,[rax]
vmovaps [rbx],ymm0
add rax,4*8
add rbx,4*8
dec rcx
ja @b }

macro addstuff{
@@: vmovaps ymm0,[rbx]
vaddps ymm0,ymm0,[rax]
vmovaps [rbx],ymm0
add rax,4*8
add rbx,4*8
dec rcx
ja @b }

macro updateweights{
@@: vmovaps ymm2,[rax]
vmovaps ymm3,[rbx]
vdivps ymm2,ymm2,ymm1
vmulps ymm2,ymm2,ymm0
vsubps ymm3,ymm3,ymm2
vmovaps [rbx],ymm3
add rax,4*8
add rbx,4*8
dec rcx
ja @b }

macro writeweights{
invoke CreateFile, f3n,GENERIC_WRITE,FILE_SHARE_WRITE,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
mov [f3],rax
mov rax,[w1]
mov rbx,[b1]
mov rcx,s1
sub rsp,8
@@: push rax
push rcx
push rbx
invoke WriteFile,[f3],rax,s0*4,temp2,0
pop rbx
push rbx
invoke WriteFile,[f3],rbx,4,temp2,0
pop rbx
pop rcx
pop rax
add rbx,4
add rax,s0*4
dec rcx
ja @b

mov rax,[w2]
mov rbx,[b2]
mov rcx,s2
@@: push rax
push rcx
push rbx
invoke WriteFile,[f3],rax,s1*4,temp2,0
pop rbx
push rbx
invoke WriteFile,[f3],rbx,4,temp2,0
pop rbx
pop rcx
pop rax
add rbx,4
add rax,s1*4
dec rcx
ja @b
add rsp,8
invoke CloseHandle,[f3]
}

macro readweights{
invoke CreateFile, f3n,GENERIC_READ,FILE_SHARE_WRITE,0,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
mov [f3],rax
mov rax,[w1]
mov rbx,[b1]
mov rcx,s1

sub rsp,8
@@: push rax
push rcx
push rbx
invoke ReadFile,[f3],rax,s0*4,temp2,0
pop rbx
push rbx
invoke ReadFile,[f3],rbx,4,temp2,0
pop rbx
pop rcx
pop rax
add rbx,4
add rax,s0*4
dec rcx
ja @b

mov rax,[w2]
mov rbx,[b2]
mov rcx,s2
@@: push rax
push rcx
push rbx
invoke ReadFile,[f3],rax,s1*4,temp2,0
pop rbx
push rbx
invoke ReadFile,[f3],rbx,4,temp2,0
pop rbx
pop rcx
pop rax
add rbx,4
add rax,s1*4
dec rcx
ja @b
add rsp,8
invoke CloseHandle,[f3]
}

macro printv0{
  local loop
mov rax,[dat]
add rax,r13
mov rbx,28
loop:
mov rcx,28
push rbx
@@: push rcx
push rax
fld dword [rax]
fstp qword [temp]
invoke printf,"%.1f ",qword [temp]
pop rax
pop rcx
add rax,4
dec rcx
ja @b
push rcx
push rax
invoke printf,<0xa,0>
pop rax
pop rcx
pop rbx
dec rbx
ja loop
invoke printf,"Curlabel %d ",rbp
invoke printf,<0xa,0>
}
macro printv1{
  local loop
mov rax,[v1]
mov rbx,10
loop:
mov rcx,10
push rbx
@@: push rcx
push rax
fld dword [rax]
fstp qword [temp]
invoke printf,"%.1f ",qword [temp]
pop rax
pop rcx
add rax,8
dec rcx
ja @b
push rcx
push rax
invoke printf,<0xa,0>
pop rax
pop rcx
pop rbx
dec rbx
ja loop
invoke printf,"Curlabel %d ",rbp
invoke printf,<0xa,0>
}
macro printv2{
mov rax,[v2]
mov rcx,10
@@: push rcx
push rax
fld dword [rax]
fstp qword [temp]
invoke printf,"%.1f ",qword [temp]
pop rax
pop rcx
add rax,8
dec rcx
ja @b
invoke printf,<0xa,0>
invoke printf,"Curlabel %d ",rbp
invoke printf,<0xa,0>
}
macro printall{
random
feedf
printv0
printv1
printv2
}
macro printtime{
invoke QueryPerformanceCounter,ended
fild qword [freq]
fild qword [ended]
fild qword [start]
fsubp st1,st0
fdiv st0,st1
fstp qword [temp]
finit
invoke printf,"%.6f ",[temp]
}
macro randomall{
	mov rbx,s0*s1
	mov rdi,[w1]
	randomizeweights
	mov rbx,s1*s2
	mov rdi,[w2]
	randomizeweights
	mov rbx,s1
	mov rdi,[b1]
	randomizeweights
	mov rbx,s2
	mov rdi,[b2]
	randomizeweights
	normalize
}

macro test2{
;from first layer to the second, curOffset is in r13
      local feed1, feed2
mov rax,[w1]
mov rdi,[v1]
mov rdx,[b1]
mov rbx,s1
mov r8,[dat]
add r8,r13
feed1:
mov rsi,r8
mov rcx, s0/8
@@:
vmovaps ymm0,[rsi]
vmovaps ymm6,[rax]
add rsi,4*8
add rax,4*8
dec rcx
ja @b
dec rbx
ja feed1
}
macro testspeed{
      local feed1
datlength=10000000000
sector=128
vxorpd ymm10,ymm10,ymm10
mov r8,[w1]
mov rsi,r8
mov r9,[gw1]
mov rdi,r9
mov rbx, datlength/(4*8*4)
feed1:
mov rsi,r8

       vaddps ymm0,ymm10,[rsi]
       add rsi,4*8
       vaddps ymm1,ymm10,[rsi]
       add rsi,4*8
       vaddps ymm2,ymm10,[rsi]
       add rsi,4*8
       vaddps ymm3,ymm10,[rsi]
       add rsi,4*8
dec rbx
ja feed1
}
;}}}}}}}}}}}}}} MACROS ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
fld qword [one]
fstp dword [one]
fld qword [stocount]
fstp dword [stocount]
fld qword [learningrate]
fstp dword [learningrate]


invoke QueryPerformanceFrequency, freq


	loaddata
	allocweights
	randomall

invoke QueryPerformanceCounter,start

macro testio{mov rax,[w2]
fld dword [rax+8]
fstp qword [temp]
invoke printf,"%.5f ",qword [temp]
writeweights
readweights
mov rax,[w2]
fld dword [rax+8]
fstp qword [temp]
invoke printf,"%.5f ",qword [temp]
jmp p}

mov r14,60000
looper: test2
dec r14
ja looper
printtime
jmp p





;randompic
;feedf
;backprop
;invoke QueryPerformanceCounter,start
;mov r14,10000
;teststuff: testspeed
;dec r14
;ja teststuff
;invoke QueryPerformanceCounter,ended
;printtime
;jmp p

mov r14,6000
trainingloop:
;calculate the average gradient
randompic
feedf
backprop
;load grad to grads
mov rax,[gb1]
mov rbx,[gsb1]
mov rcx,s1/8
movestuff

mov rax,[gw1]
mov rbx,[gsw1]
mov rcx,s1*s0/8
movestuff

mov rax,[gb2]
mov rbx,[gsb2]
mov rcx,(s2+7)/8
movestuff

mov rax,[gw2]
mov rbx,[gsw2]
mov rcx,s2*s1/8
movestuff

stochastic=10

;add grad to grads
mov r12,stochastic-1
stocloop:
randompic
feedf
backprop
mov rax,[gb1]
mov rbx,[gsb1]
mov rcx,s1/8
addstuff

mov rax,[gw1]
mov rbx,[gsw1]
mov rcx,s1*s0/8
addstuff

mov rax,[gb2]
mov rbx,[gsb2]
mov rcx,(s2+7)/8
addstuff

mov rax,[gw2]
mov rbx,[gsw2]
mov rcx,s2*s1/8
addstuff

dec r12
ja stocloop


	;divide by stocount to get average gradient and update weights
	vbroadcastss ymm0,dword [learningrate]
	vbroadcastss ymm1,dword [stocount]
	mov rax,[gsb1]
	mov rbx,[b1]
	mov rcx,s1/8
	updateweights

	mov rax,[gsw1]
	mov rbx,[w1]
	mov rcx,s1*s0/8
	updateweights

	mov rax,[gsb2]
	mov rbx,[b2]
	mov rcx,(s2+7)/8
	updateweights

	mov rax,[gsw2]
	mov rbx,[w2]
	mov rcx,s2*s1/8
	updateweights

dec r14
ja trainingloop


invoke QueryPerformanceCounter,ended
printtime

writeweights

mov qword [temp],0
stmxcsr dword [temp]
invoke printf,"%X ",[temp]


p: invoke printf,"END",
invoke Sleep,-1
invoke ExitProcess,0

section '.data' data readable writeable
dat dq 0
dattemp dq 0
labels dq 0
labelstemp dq 0
picnum dq 0
w1 dq 0
w2 dq 0
b1 dq 0
b2 dq 0
v1 dq 0
v2 dq 0
gw1 dq 0
gsw1 dq 0
gw2 dq 0
gsw2 dq 0
gb1 dq 0
gsb1 dq 0
gb2 dq 0
gsb2 dq 0

f1n db 'D:\Java\Projekt\train-images.idx3-ubyte',0
f2n db 'D:\Java\Projekt\train-labels.idx1-ubyte',0
f3n db 'Weightsasmfloat.txt',0
align 16
f1s dq 0
f2s dq 0
f1 dq 0
f2 dq 0
f3 dq 0
temp dq 0
temp2 dq 0
powtwo dq -63
maxintensity dq 255
allones dq 2
freq dq 0
start dq 0
ended dq 0
stocount dq 10.0f
learningrate dq 0.05f
one dq 1.0f

ws1 dq s0 ;w1 scale
ws1d dq 0.2f  ;w1 scale from dispersion of first (input) layer
ws2 dq s1 ;w2 scale

msg db "hello",0

section ".idata" import data readable

library kernel32,'KERNEL32.DLL',\
	user32,'USER32.DLL',\
	msvcrt,'msvcrt.dll'
include 'API\USER32.INC'
include 'API\KERNEL32.INC'

import msvcrt,printf,'printf',\
	      rand_s,'rand_s',\
	      rand,'rand'