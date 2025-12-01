; animation.asm
; 编译: ml64 animation.asm /link /subsystem:windows /entry:WinMain kernel32.lib user32.lib gdi32.lib

option casemap:none

; ==================== 常量定义 ====================
NULL                    equ 0
WS_OVERLAPPEDWINDOW     equ 0CF0000h
WS_VISIBLE              equ 10000000h
CS_HREDRAW              equ 2
CS_VREDRAW              equ 1
IDC_ARROW               equ 32512
IDI_APPLICATION         equ 32512
COLOR_WINDOW            equ 5
WM_DESTROY              equ 2
WM_PAINT                equ 0Fh
WM_TIMER                equ 113h
TIMER_ID                equ 1
WINDOW_SIZE             equ 512

; ==================== 结构定义 ====================
WNDCLASSEX struct
    cbSize          dd ?
    style           dd ?
    lpfnWndProc     dq ?
    cbClsExtra      dd ?
    cbWndExtra      dd ?
    hInstance       dq ?
    hIcon           dq ?
    hCursor         dq ?
    hbrBackground   dq ?
    lpszMenuName    dq ?
    lpszClassName   dq ?
    hIconSm         dq ?
WNDCLASSEX ends

POINT struct
    x dd ?
    y dd ?
POINT ends

MSG struct
    hWnd    dq ?
    message dd ?
            dd ?
    wParam  dq ?
    lParam  dq ?
    time    dd ?
    pt      POINT <>
            dd ?
MSG ends

RECT struct
    left    dd ?
    top     dd ?
    right   dd ?
    bottom  dd ?
RECT ends

PAINTSTRUCT struct
    hdc         dq ?
    fErase      dd ?
    rcPaint     RECT <>
    fRestore    dd ?
    fIncUpdate  dd ?
    rgbReserved db 32 dup(?)
PAINTSTRUCT ends

; ==================== 外部函数 ====================
extern GetModuleHandleA:proc
extern RegisterClassExA:proc
extern CreateWindowExA:proc
extern GetMessageA:proc
extern TranslateMessage:proc
extern DispatchMessageA:proc
extern DefWindowProcA:proc
extern PostQuitMessage:proc
extern LoadIconA:proc
extern LoadCursorA:proc
extern BeginPaint:proc
extern EndPaint:proc
extern GetTickCount64:proc
extern SetTimer:proc
extern KillTimer:proc
extern InvalidateRect:proc
extern CreateSolidBrush:proc
extern FillRect:proc
extern DeleteObject:proc
extern ExitProcess:proc
extern GetClientRect:proc

; ==================== 数据段 ====================
.data
    szClassName     db "AnimSquareClass", 0
    szTitle         db "Square Animation - Size = seconds mod 512", 0
    startTick       dq 0
    hMainWnd        dq 0
    hInst           dq 0

.data?
    wc          WNDCLASSEX <>
    msgStruct   MSG <>
    ps          PAINTSTRUCT <>
    rcClient    RECT <>
    rcSquare    RECT <>

; ==================== 代码段 ====================
.code

; ==================== 主函数 ====================
WinMain proc
    sub rsp, 88h                            ; 栈空间 (shadow space + 参数 + 对齐)
    
    ; 获取模块句柄
    xor ecx, ecx
    call GetModuleHandleA
    mov hInst, rax
    
    ; -------- 注册窗口类 --------
    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    lea rax, WndProc
    mov wc.lpfnWndProc, rax
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov rax, hInst
    mov wc.hInstance, rax
    
    ; 加载图标
    xor ecx, ecx
    mov edx, IDI_APPLICATION
    call LoadIconA
    mov wc.hIcon, rax
    mov wc.hIconSm, rax
    
    ; 加载光标
    xor ecx, ecx
    mov edx, IDC_ARROW
    call LoadCursorA
    mov wc.hCursor, rax
    
    mov wc.hbrBackground, COLOR_WINDOW + 1
    mov wc.lpszMenuName, 0
    lea rax, szClassName
    mov wc.lpszClassName, rax
    
    lea rcx, wc
    call RegisterClassExA
    
    ; -------- 创建窗口 --------
    xor ecx, ecx                            ; dwExStyle = 0
    lea rdx, szClassName
    lea r8, szTitle
    mov r9d, WS_OVERLAPPEDWINDOW or WS_VISIBLE
    mov dword ptr [rsp+20h], 100            ; X
    mov dword ptr [rsp+28h], 100            ; Y
    mov dword ptr [rsp+30h], 528            ; Width  (512 + 边框)
    mov dword ptr [rsp+38h], 551            ; Height (512 + 标题栏 + 边框)
    mov qword ptr [rsp+40h], 0              ; hWndParent
    mov qword ptr [rsp+48h], 0              ; hMenu
    mov rax, hInst
    mov [rsp+50h], rax                      ; hInstance
    mov qword ptr [rsp+58h], 0              ; lpParam
    call CreateWindowExA
    mov hMainWnd, rax
    
    ; 记录窗口创建时间
    call GetTickCount64
    mov startTick, rax
    
    ; 设置定时器 (每秒更新一次)
    mov rcx, hMainWnd
    mov edx, TIMER_ID
    mov r8d, 100                            ; 100ms 刷新
    xor r9, r9
    call SetTimer
    
    ; -------- 消息循环 --------
MsgLoop:
    lea rcx, msgStruct
    xor edx, edx
    xor r8, r8
    xor r9, r9
    call GetMessageA
    test eax, eax
    jle ExitLoop
    
    lea rcx, msgStruct
    call TranslateMessage
    lea rcx, msgStruct
    call DispatchMessageA
    jmp MsgLoop
    
ExitLoop:
    mov ecx, dword ptr msgStruct.wParam
    call ExitProcess
WinMain endp

; ==================== 窗口过程 ====================
WndProc proc
    push rbp
    mov rbp, rsp
    sub rsp, 0C0h                           ; 本地变量空间
    
    ; 保存参数到 home space
    mov [rbp+10h], rcx                      ; hWnd
    mov [rbp+18h], edx                      ; uMsg
    mov [rbp+20h], r8                       ; wParam
    mov [rbp+28h], r9                       ; lParam
    
    ; 消息分发
    cmp edx, WM_DESTROY
    je OnDestroy
    cmp edx, WM_PAINT
    je OnPaint
    cmp edx, WM_TIMER
    je OnTimer
    jmp OnDefault
    
; -------- WM_DESTROY --------
OnDestroy:
    mov rcx, [rbp+10h]
    mov edx, TIMER_ID
    call KillTimer
    
    xor ecx, ecx
    call PostQuitMessage
    xor eax, eax
    jmp Epilog
    
; -------- WM_TIMER --------
OnTimer:
    mov rcx, [rbp+10h]
    xor edx, edx                            ; NULL rect = 整个窗口
    xor r8d, r8d                            ; bErase = FALSE
    call InvalidateRect
    xor eax, eax
    jmp Epilog
    
; -------- WM_PAINT --------
OnPaint:
    ; BeginPaint
    mov rcx, [rbp+10h]
    lea rdx, ps
    call BeginPaint
    mov [rbp-8h], rax                       ; 保存 hdc
    
    ; 获取客户区大小用于清除背景
    mov rcx, [rbp+10h]
    lea rdx, rcClient
    call GetClientRect
    
    ; -------- 计算正方形大小 --------
    ; squareSize = (currentTime - startTime) / 1000 % 512
    call GetTickCount64
    sub rax, startTick                      ; 经过的毫秒数
    
    xor edx, edx
    mov rcx, 100
    div rcx                                 ; rax = 秒数
    
    xor edx, edx
    mov rcx, WINDOW_SIZE
    div rcx                                 ; rdx = 秒数 % 512
    
    ; 如果余数为0，设为1（确保可见）
    test edx, edx
    jnz SizeOk
    mov edx, 1
SizeOk:
    mov [rbp-10h], edx                      ; squareSize
    
    ; -------- 创建红色画刷 --------
    mov ecx, 000000FFh                      ; BGR: 红色
    call CreateSolidBrush
    mov [rbp-18h], rax                      ; hBrushRed
    
    ; -------- 设置正方形矩形 --------
    ; 正方形从左上角 (0,0) 开始
    mov rcSquare.left, 0
    mov rcSquare.top, 0
    mov eax, [rbp-10h]
    mov rcSquare.right, eax
    mov rcSquare.bottom, eax
    
    ; -------- 填充正方形 --------
    mov rcx, [rbp-8h]                       ; hdc
    lea rdx, rcSquare
    mov r8, [rbp-18h]                       ; hBrush
    call FillRect
    
    ; -------- 清理画刷 --------
    mov rcx, [rbp-18h]
    call DeleteObject
    
    ; EndPaint
    mov rcx, [rbp+10h]
    lea rdx, ps
    call EndPaint
    
    xor eax, eax
    jmp Epilog
    
; -------- 默认处理 --------
OnDefault:
    mov rcx, [rbp+10h]
    mov edx, [rbp+18h]
    mov r8, [rbp+20h]
    mov r9, [rbp+28h]
    call DefWindowProcA
    jmp Epilog
    
Epilog:
    mov rsp, rbp
    pop rbp
    ret
WndProc endp

end
