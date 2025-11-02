section .bss 
source_fd resd 1 ; 源文件描述符
dest_fd resd 1 ; 目標文件描述符
buffer resb 4096 ; 讀寫緩衝區 (4KB)
source_size resd 1 ; 源文件大小

section .data
source_path db 'source.txt', 0 ; 源文件路徑
target_dir db '/home/paulboul/test_replicate', 0 ; 目標目錄路徑

section .text
global _start

_start:
    ; 打開源文件讀取內容
    mov eax, 5 ; syscall: sys_open
    mov ebx, source_path
    xor ecx, ecx ; O_RDONLY
    int 0x80
    
    test eax, eax
    js open_failed
    mov [source_fd], eax
    
    ; 讀取源文件內容到緩衝區
    mov eax, 3 ; syscall: sys_read
    mov ebx, [source_fd]
    mov ecx, buffer
    mov edx, 4096
    int 0x80
    mov [source_size], eax
    
    ; 關閉源文件
    mov eax, 6 ; syscall: sys_close
    mov ebx, [source_fd]
    int 0x80
    
    ; 開始處理目標目錄
    mov esi, target_dir
    call process_directory
    
    ; 正常退出
    mov eax, 1 ; syscall: sys_exit
    xor ebx, ebx ; exit status 0
    int 0x80

open_failed:
    mov eax, 1
    mov ebx, 1 ; exit status 1
    int 0x80

; 遞歸處理目錄
; 輸入: ESI = 目錄路徑指針
process_directory:
    push ebp
    mov ebp, esp
    sub esp, 9232 ; 分配堆棧空間
    ; [ebp-4] = 目錄文件描述符
    ; [ebp-8] = 目錄路徑指針
    ; [ebp-12] = 當前偏移量
    ; [ebp-16] = 讀取的字節數
    ; [ebp-8208] 開始 = dir_buffer (8192 bytes)
    ; [ebp-9232] 開始 = file_path (1024 bytes)
    
    mov [ebp-8], esi
    
    ; 打開目錄
    mov eax, 5
    mov ebx, esi
    mov ecx, 0x10000 ; O_RDONLY | O_DIRECTORY
    int 0x80
    test eax, eax
    js .cleanup
    mov [ebp-4], eax

.read_entries:
    ; 讀取目錄項
    mov eax, 220 ; syscall: sys_getdents64
    mov ebx, [ebp-4]
    lea ecx, [ebp-8208]
    mov edx, 8192
    int 0x80
    
    cmp eax, 0
    jle .close_dir
    
    mov [ebp-16], eax
    mov dword [ebp-12], 0

.process_entry:
    mov eax, [ebp-12]
    cmp eax, [ebp-16]
    jge .read_entries
    
    ; 獲取當前目錄項
    lea esi, [ebp-8208]
    add esi, [ebp-12]
    
    movzx edx, word [esi+16] ; d_reclen
    movzx ecx, byte [esi+18] ; d_type
    lea ebx, [esi+19] ; d_name
    
    ; 跳過 "." 和 ".."
    cmp byte [ebx], '.'
    jne .build_path
    cmp byte [ebx+1], 0
    je .next_entry
    cmp byte [ebx+1], '.'
    jne .build_path
    cmp byte [ebx+2], 0
    je .next_entry

.build_path:
    ; 保存寄存器
    push edx
    push ecx
    
    ; 構建完整路徑
    lea edi, [ebp-9232]
    mov esi, [ebp-8]
    
.copy_dir:
    lodsb
    test al, al
    jz .add_slash
    stosb
    jmp .copy_dir
    
.add_slash:
    mov al, '/'
    stosb
    
    lea esi, [ebp-8208]
    add esi, [ebp-12]
    add esi, 19
    
.copy_name:
    lodsb
    test al, al
    jz .check_type
    stosb
    jmp .copy_name

.check_type:
    xor al, al
    stosb
    
    pop ecx ; 恢復 d_type
    pop edx ; 恢復 d_reclen
    
    cmp ecx, 4 ; 目錄
    je .process_subdir
    cmp ecx, 8 ; 普通文件
    je .write_file
    jmp .next_entry

.process_subdir:
    ; 遞歸處理子目錄
    push edx
    lea esi, [ebp-9232]
    call process_directory
    pop edx
    jmp .next_entry

.write_file:
    ; 寫入文件
    push edx
    
    mov eax, 5
    lea ebx, [ebp-9232]
    mov ecx, 0x241 ; O_WRONLY|O_CREAT|O_TRUNC
    mov edx, 0644o
    int 0x80
    
    test eax, eax
    js .skip_write
    
    mov [dest_fd], eax
    
    mov eax, 4 ; syscall: sys_write
    mov ebx, [dest_fd]
    mov ecx, buffer
    mov edx, [source_size]
    int 0x80
    
    mov eax, 6 ; syscall: sys_close
    mov ebx, [dest_fd]
    int 0x80

.skip_write:
    pop edx

.next_entry:
    add [ebp-12], edx
    jmp .process_entry

.close_dir:
    mov eax, 6
    mov ebx, [ebp-4]
    int 0x80

.cleanup:
    mov esp, ebp
    pop ebp
    ret
