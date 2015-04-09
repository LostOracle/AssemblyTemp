
@@@ pcDuino devices
@@@ -----------------------------------------------------------
@@@ This file provides a function "IO_init" that will
@@@ map some devices into the user program's memory
@@@ space.  Pointers to the devices are stored in
@@@ global variables, and the user program can then
@@@ use those pointers to access the device registers.
@@@ -----------------------------------------------------------
	.data
@@@ -----------------------------------------------------------
@@@ The following global variables will hold the addresses of
@@@ the devices that can be accessed directly after IO_init
@@@ has been called.
	.global	ccubase
ccubase	:	.word	0
	.global	gpiobase
gpiobase:	.word	0
	.global	pwmbase
pwmbase	:	.word	0
	.global	uart2base
uart2base:	.word	0

@@@ These are the physical addresses for the I/O devices.
	@@ Base Physical Address of the Clock Control Unit
	.equ	CCU_BASE,  0x01C20000
	@@ Base Physical Address of the GPIO device
	.equ	GPIO_BASE, 0x01C20800
	@@ Base Physical Address of the PWM device
	.equ	PWM_BASE,  0x01C20C00
	@@ Base Physical Address of the UART2 device
	.equ	UART2_BASE,0x01C28800

	.equ	MAP_FAILED,-1
	.equ	MAP_SHARED, 1
	.equ	PROT_READ,  1
	.equ	PROT_WRITE, 2
	.equ BLOCK_SIZE,(4*1024)
	
	@@ some constants from fcntl.h
	.equ	O_RDONLY,   00000000
	.equ	O_WRONLY,   00000001
	.equ	O_RDWR,	    00000002
	.equ	O_CREAT,    00000100
	.equ	O_EXCL,	    00000200
	.equ	O_NOCTTY,   00000400
	.equ	O_TRUNC,    00001000
	.equ	O_APPEND,   00002000
	.equ	O_NONBLOCK, 00004000
	.equ	O_NDELAY,   O_NONBLOCK
	.equ	O_SYNC,     00010000
	.equ	O_FSYNC,    O_SYNC
	.equ	O_ASYNC,    00020000

memdev:		.asciz	"/dev/mem"
successstr:	.asciz	"Successfully opened /dev/mem\n"
mappedstr:	.asciz	"Mapped %s device at 0x%08X\n"
openfailed:	.asciz	"IO_init: failed to open /dev/mem: "
mapfailedmsg:	.asciz	"IO_init: mmap of %s failed: "
ccustr:		.asciz	"CCU"
gpiostr:	.asciz	"GPIO"
pwmstr:		.asciz	"PWM"	
uart2str:	.asciz	"UART2"	

@@@ -----------------------------------------------------------
	.text
@@@ -----------------------------------------------------------
	.global	IO_init
IO_init:
	stmfd	sp!,{r4,r5,lr}
	@@ Try to open /dev/mem	
	ldr	r0,=memdev	@ load address of "/dev/mem"
	ldr	r1,=(O_RDWR + O_SYNC)
	bl	open		@ call the open syscall
	cmp	r0,#0		@ check result
	bge	init_opened	@ if open failed,
	ldr	r0,=openfailed	@ print message and exit 
	bl	printf
	bl      __errno_location
        ldr     r0, [r0]
        bl      strerror
        bl      perror
	mov	r5,#0		@ return 0 for failure
	b	init_exit
init_opened:
	@@ Open succeeded. Print message and  map the devices 
	mov	r4,r0		@ move file descriptor to r4
	ldr	r0,=successstr
	bl	printf
	@@ Map the GPIO device
	ldr	r5,=GPIO_BASE
	bl	trymap
	cmp	r5,#MAP_FAILED
	ldrne	r0,=gpiobase	@ if succeeded, load pointer
	ldreq	r1,=gpiostr	@ if failed, load string
	strne	r5,[r0]		@ if succeeded,	store value
	beq	map_failed_exit	@ if failed, print message 
	ldr	r0,=mappedstr   @ print success message
	ldr	r1,=gpiostr
	ldr	r2,=gpiobase
	ldr	r2,[r2]
	bl	printf
	@@ Map the PWM device
	ldr	r5,=PWM_BASE
	bl	trymap
	cmp	r5,#MAP_FAILED
	ldrne	r0,=pwmbase	@ if succeeded, load pointer
	ldreq	r1,=pwmstr      @ if failed, load string    
	strne	r5,[r0]		@ if succeeded,	store value 
	beq	map_failed_exit @ if failed, print message  
	ldr	r0,=mappedstr	@ print success message     
	ldr	r1,=pwmstr
	ldr	r2,=pwmbase
	ldr	r2,[r2]
	bl	printf
	@@ Map the clock control unit
	ldr	r5,=CCU_BASE
	bl	trymap
	cmp	r5,#MAP_FAILED
	ldrne	r0,=ccubase	@ if succeeded, load pointer
	ldreq	r1,=ccustr	@ if failed, load string    
	strne	r5,[r0]		@ if succeeded,	store value 
	beq	map_failed_exit	@ if failed, print message  
	ldr	r0,=mappedstr   @ print success message     
	ldr	r1,=ccustr
	ldr	r2,=ccubase
	ldr	r2,[r2]
	bl	printf
	@@ Map UART2
	ldr	r5,=UART2_BASE
	bl	trymap
	cmp	r5,#MAP_FAILED
	ldrne	r0,=uart2base	@ if succeeded, load pointer
	ldreq	r1,=uart2str	@ if failed, load string    
	strne	r5,[r0]		@ if succeeded,	store value 
	beq	map_failed_exit	@ if failed, print message  
	ldr	r0,=mappedstr	@ print success message     
	ldr	r1,=uart2str
	ldr	r2,=uart2base
	ldr	r2,[r2]
	bl	printf
	@@ All mmaps have succeded.
	@@ Close file and return 1 for success
	mov	r5,#1
	b	init_close
map_failed_exit:
	@@ At least one mmap failed. Print error,
	@@ unmap everthing and return
	ldr	r0,=mapfailedmsg
	bl	printf
	bl      __errno_location
	ldr     r0, [r0, #0]
	bl      strerror
	bl      perror
	bl	IO_close
	mov	r5,#0	
init_close:
	mov	r0,r4		@ close /dev/mem
	bl	close
init_exit:	
	mov	r0,r5		@ move return code to r0
	ldmfd	sp!,{r4,r5,pc}	@ return
@@@ -----------------------------------------------------------
@@@ Calls mmap.  Does not conform to ARM function call standard.
@@@ parameters are passed in r0-r5.  Return value is in r5.
trymap:	stmfd	sp!,{lr}
	mov	r0,r5		@ request mapping at phys addr
	mov	r1,#BLOCK_SIZE
	mov	r2,#(PROT_READ + PROT_WRITE)
	mov	r3,#MAP_SHARED
	stmfd	sp!,{r4,r5}
	bl	mmap
	add	sp,sp,#8
	mov	r5,r0		@ copy return code to r5
	ldmfd	sp!,{pc}
@@@ -----------------------------------------------------------
@@@ IO_close unmaps all of the devices
	.global	IO_close
IO_close:
	stmfd	sp!,{r4,r5,lr}
	ldr	r4,=ccubase	@ get address of first pointer
	mov	r5,#4		@ there are 4 pointers
IO_closeloop:
	ldr	r0,[r4]		@ load address of device
	mov	r1,#BLOCK_SIZE
	cmp	r0,#0
	blgt	munmap		@ unmap the device
	mov	r0,#0
	str	r0,[r4],#4	@ store and increment
	subs	r5,r5,#1
	bgt	IO_closeloop
	ldmfd	sp!,{r4,r5,pc}
