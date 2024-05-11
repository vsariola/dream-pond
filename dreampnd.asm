XRES equ 1024
YRES equ 768
STEPS equ 18
ITERS equ 31
XCOORD equ 0xFFE8
YCOORD equ 0xFFEC

org 100h

; The video mode setup and bankswitchingloop are based on code by TomCat, see
; https://www.pouet.net/prod.php?which=93549

main:
    push    0xa000
    pop     es
    scasw
    cwd
    mov     bx, 0x118
.nextbank:
    add     ax, 0x4F02
    int     10h
    sub     bx, bx
.nextpixel:
    mov     bp, BASE
    mov     si, XRES*4
    pusha
    xchg    ax, di
    div     si
    sub     ax, YRES/2
    sub     dh, XRES/2*4/256
    pusha                     ; x at [bx+XCOORD], y at [bx+YCOORD]
    fld     dword [c_camx+bp-BASE]
    fld     dword [c_camy+bp-BASE]
    fldz    ; stack: p.z p.y p.x
    fldz
    fst     dword [bx] ; glow = 0.0
.reflectloop:
    xor     dx, dx
.marchloop:
    ; X:
    fild    word [bx+XCOORD]
    fmul    st0, st1
    fidiv   word [c_stepsizediv_x+bp-BASE]
    faddp   st4
    ; Y:
    fild    word [bx+YCOORD]
    fmul    st0, st1
    fidiv   word [c_stepsizediv_y+bp-BASE]
    faddp   st3
    ; Z:
    fdiv    dword [c_stepsizediv_z+bp-BASE]
    faddp   st1
    fld     st1                     ;
    fchs                            ; r = -p.y
    fstp    dword [si]              ; store r
    fld     st0
    fld     st2
    fld     st4                     ; stack: t.x t.y t.z r p.z p.y p.x
    call    bp
    jc      .out                    ; if (dist < MINDIST) break;
    inc     dx
    cmp     dx, STEPS               ; i < STEPS (the loop had dx increasing instead of decreasing to avoid taking 20-steps later)
    jl      .marchloop
.out:
    mov     word [bx+YCOORD], -400
    dec     si
    jpe      .reflectloop
    fstp    st0
    mov     [si], dx
    fild    word [si]
    fmul    dword [c_colorscale+bp-BASE]
    fmul    st0                     ; float s =  float(i)*COLORSCALE;
    popa
    popa
    fstp    st1
    fstp    st1
    fstp    st1
    fadd    dword [bx] ; col += glow
    fsin
    fabs
    fimul   word [c_255+bp-BASE]
    fistp   word [si]
    lodsb
    stosb
    stosb
    stosb
    stosb
    test    di, di
    jnz     .nextpixel
    inc     dx
    mov     al, 3
    cmp     dl, XRES*YRES/16384
    jne     .nextbank
.forever:
    jmp     .forever ; No extra cool points for clean exits :(

BASE EQU $

inner:
    mov     cl, ITERS
.maploop:
    fld     st0
    fsin
    fld     st2
    fsin
    fmulp   st1, st0
    fld     st3
    fsin
    fmulp   st1, st0
    fadd    dword [si]     ; r+sin(t.x)*sin(t.y)*sin(t.z)
    fmul    dword [c_rscale+bp-BASE]
    fstp    dword [si]
    fadd    st0          ; t.x += t.x;
    fxch    st0, st2
    fxch    st0, st1
    loop    .maploop
.clearloop:
    fstp    st0          ; discard t.xyz from the stack
    inc     cx
    jpo     .clearloop
    fld     dword [si]
    fdiv   dword [c_rdiv+bp-BASE]
    fld     st0
    fmul    st0   ; dist*dist
    fimul   word  [c_255+bp-BASE]
    fld1
    faddp   st1, st0 ; 1+dist*dist*glowdecay
    fdivr   dword [c_glowamount+bp-BASE]
    fadd    dword [bx] ; glow += glowamount/(1+dist*dist*glowdecay)
    fstp    dword [bx]
    ; is dist < MINDIST?
    fcom    dword [c_mindist+bp-BASE]
    fnstsw  ax
    sahf
    ret

; floating constants truncated using https://www.h-schmidt.net/FloatConverter/IEEE754.html
c_mindist:
    dd     0.0001

c_glowamount equ $-2
    ;dd      0.01
    dw     0x3c23

c_stepsizediv_y:
    dw     2343

c_stepsizediv_x:
    dw     9372

c_stepsizediv_z:
    dd     3.05078125

c_rscale:
    dd     1.2599210498948732

c_rdiv:
    dd   1290.1591550923508

c_255:
    dw     255

c_camy:
    dd     -0.008

c_camx:
    dd     1.351

c_colorscale equ $-2
    ;dd      0.05555555555555555
    dw  0x3d63