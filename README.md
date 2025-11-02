# Replicate - 組合語言文件複製工具

## 程式簡介

這是一個使用 32-bit x86 組合語言編寫的文件複製工具，能夠遞歸遍歷指定目錄及其所有子目錄，將源文件的內容寫入到所有找到的文件中。

## 功能特點

- 讀取源文件 source.txt 的內容
- 遞歸遍歷目標目錄 /path/to/test_folder
- 將源文件內容寫入目標目錄下的所有文件
- 支持任意深度的子目錄結構
- 純組合語言實現，無外部依賴

## 編譯與執行

### 編譯
```bash
nasm -f elf32 replicate.s -o replicate.o
ld -m elf_i386 replicate.o -o replicate
```

### 執行
```bash
./replicate
```

## 程式結構

### 記憶體區段

#### .bss 段
未初始化的數據區段
- source_fd: 源文件描述符 (4 bytes)
- dest_fd: 目標文件描述符 (4 bytes)
- buffer: 讀寫緩衝區 (4096 bytes)
- source_size: 源文件大小 (4 bytes)

#### .data 段
已初始化的數據區段
- source_path: 源文件路徑字符串
- target_dir: 目標目錄路徑字符串

#### .text 段
程式碼區段，包含可執行指令

### 主要函數

#### _start
程式入口點
1. 打開並讀取源文件
2. 調用 process_directory 處理目錄
3. 正常退出

#### process_directory
遞歸處理目錄函數
1. 打開目錄
2. 讀取目錄項 (使用 getdents64)
3. 遍歷每個目錄項
4. 如果是文件則寫入內容
5. 如果是目錄則遞歸調用自身

## 組合語言語法複習

### 基本語法結構

```asm
標籤:
    指令 目標操作數, 源操作數 ; 註釋
```

### 常用指令

#### 數據移動指令

**MOV** - 移動數據
```asm
mov eax, 5          ; 將立即數 5 移動到 EAX 寄存器
mov ebx, eax        ; 將 EAX 的值移動到 EBX
mov [source_fd], eax ; 將 EAX 的值存入記憶體位置 source_fd
mov ecx, [buffer]   ; 將記憶體 buffer 的值載入 ECX
```

**LEA** - 載入有效地址
```asm
lea edi, [ebp-9232] ; 將地址 ebp-9232 載入 EDI
```

**PUSH / POP** - 堆棧操作
```asm
push ebp            ; 將 EBP 壓入堆棧
pop ebp             ; 從堆棧彈出值到 EBP
```

#### 算術指令

**ADD** - 加法
```asm
add esi, [ebp-12]   ; ESI = ESI + [ebp-12]
```

**SUB** - 減法
```asm
sub esp, 9232       ; ESP = ESP - 9232 (分配堆棧空間)
```

**XOR** - 異或運算 (常用於清零)
```asm
xor ecx, ecx        ; ECX = 0 (自己和自己異或結果為 0)
xor al, al          ; AL = 0
```

#### 比較與跳轉指令

**CMP** - 比較
```asm
cmp eax, 0          ; 比較 EAX 和 0
cmp ecx, 4          ; 比較 ECX 和 4
```

**TEST** - 測試 (進行 AND 運算但不保存結果)
```asm
test eax, eax       ; 檢查 EAX 是否為 0
test al, al         ; 檢查 AL 是否為 0
```

**JMP** - 無條件跳轉
```asm
jmp .next_entry     ; 跳轉到 .next_entry 標籤
```

**條件跳轉**
```asm
je  .label          ; Jump if Equal (相等時跳轉)
jne .label          ; Jump if Not Equal (不相等時跳轉)
jg  .label          ; Jump if Greater (大於時跳轉)
jl  .label          ; Jump if Less (小於時跳轉)
jge .label          ; Jump if Greater or Equal (大於等於時跳轉)
jle .label          ; Jump if Less or Equal (小於等於時跳轉)
js  .label          ; Jump if Sign (負數時跳轉)
```

#### 字符串操作指令

**LODSB** - 從 [ESI] 載入字節到 AL，然後 ESI++
```asm
lodsb               ; AL = [ESI], ESI = ESI + 1
```

**STOSB** - 將 AL 存儲到 [EDI]，然後 EDI++
```asm
stosb               ; [EDI] = AL, EDI = EDI + 1
```

#### 擴展指令

**MOVZX** - 零擴展移動
```asm
movzx edx, word [esi+16]  ; 將 16-bit 的值擴展成 32-bit 移到 EDX
movzx ecx, byte [esi+18]  ; 將 8-bit 的值擴展成 32-bit 移到 ECX
```

#### 函數調用

**CALL** - 調用函數
```asm
call process_directory    ; 調用函數，返回地址壓入堆棧
```

**RET** - 返回
```asm
ret                       ; 從堆棧彈出返回地址並跳轉
```

#### 系統調用

**INT 0x80** - 觸發系統調用 (32-bit Linux)
```asm
int 0x80                  ; 執行系統調用
```

### 寄存器說明

#### 通用寄存器 (32-bit)

- **EAX**: 累加器，常用於系統調用號和返回值
- **EBX**: 基址寄存器，常用於系統調用的第一個參數
- **ECX**: 計數器，常用於系統調用的第二個參數
- **EDX**: 數據寄存器，常用於系統調用的第三個參數
- **ESI**: 源索引寄存器，用於字符串操作
- **EDI**: 目標索引寄存器，用於字符串操作

#### 指針和基址寄存器

- **EBP**: 基址指針，用於訪問函數的堆棧框架
- **ESP**: 堆棧指針，指向堆棧頂端

#### 8-bit 寄存器

- **AL**: EAX 的低 8 位
- **AH**: EAX 的高 8 位 (第 8-15 位)

### 常用系統調用 (32-bit Linux)

系統調用通過 EAX 指定調用號，參數依次通過 EBX, ECX, EDX 傳遞。

| 調用號 | 系統調用 | EBX | ECX | EDX | 說明 |
|--------|----------|-----|-----|-----|------|
| 1 | sys_exit | 退出碼 | - | - | 退出程式 |
| 3 | sys_read | fd | buffer | count | 讀取文件 |
| 4 | sys_write | fd | buffer | count | 寫入文件 |
| 5 | sys_open | 路徑 | flags | mode | 打開文件 |
| 6 | sys_close | fd | - | - | 關閉文件 |
| 220 | sys_getdents64 | fd | buffer | count | 讀取目錄項 |

### 文件操作標誌

#### 打開文件標誌 (O_FLAGS)

```asm
0x0000        ; O_RDONLY - 唯讀
0x0001        ; O_WRONLY - 唯寫
0x0040        ; O_CREAT - 不存在則創建
0x0200        ; O_TRUNC - 截斷文件為 0
0x0241        ; O_WRONLY|O_CREAT|O_TRUNC - 寫入模式組合
0x10000       ; O_DIRECTORY - 必須是目錄
```

#### 文件權限 (八進制)

```asm
0644o         ; rw-r--r-- (擁有者讀寫，其他人只讀)
```

### 記憶體尋址模式

```asm
mov eax, [ebx]          ; 間接尋址: EAX = 記憶體[EBX]
mov eax, [ebx+16]       ; 基址+偏移: EAX = 記憶體[EBX+16]
mov eax, [ebp-8]        ; 負偏移 (堆棧): EAX = 記憶體[EBP-8]
lea eax, [ebp-9232]     ; 載入地址而非內容
```

### 標籤規則

#### 全局標籤
```asm
_start:                 ; 全局標籤 (無點號前綴)
process_directory:      ; 全局標籤
```

#### 局部標籤
```asm
.read_entries:          ; 局部標籤 (點號前綴)
.loop:                  ; 只在當前全局標籤範圍內有效
```

### 數據定義

```asm
db  'text', 0           ; Define Byte - 定義字節
dw  1234                ; Define Word - 定義 2 字節
dd  12345678            ; Define Doubleword - 定義 4 字節

resb 4096               ; Reserve Bytes - 保留字節空間
resd 1                  ; Reserve Doubleword - 保留 4 字節空間
```

### 堆棧操作模式

```asm
push ebp                ; 保存舊的基址指針
mov ebp, esp            ; 建立新的堆棧框架
sub esp, 9232           ; 分配局部變量空間

; 使用 [ebp-N] 訪問局部變量
mov [ebp-4], eax        ; 保存值到局部變量

mov esp, ebp            ; 釋放局部變量空間
pop ebp                 ; 恢復舊的基址指針
ret                     ; 返回
```

## getdents64 目錄項結構

```c
struct linux_dirent64 {
    u64        d_ino;      // 偏移 0: inode 號 (8 bytes)
    i64        d_off;      // 偏移 8: 下一個目錄項的偏移 (8 bytes)
    unsigned short d_reclen; // 偏移 16: 這個目錄項的長度 (2 bytes)
    unsigned char  d_type;   // 偏移 18: 文件類型 (1 byte)
    char       d_name[];     // 偏移 19: 文件名 (變長)
}
```

### 文件類型 (d_type)

- 4: DT_DIR - 目錄
- 8: DT_REG - 普通文件

## 程式流程圖

```
_start
  |
  +-- 打開並讀取 source.txt
  |
  +-- 調用 process_directory(target_dir)
  |     |
  |     +-- 打開目錄
  |     |
  |     +-- 循環讀取目錄項
  |           |
  |           +-- 跳過 "." 和 ".."
  |           |
  |           +-- 構建完整路徑
  |           |
  |           +-- 檢查類型
  |                 |
  |                 +-- 如果是目錄 -> 遞歸調用 process_directory
  |                 |
  |                 +-- 如果是文件 -> 打開並寫入 buffer 內容
  |
  +-- 退出程式
```

## 範例

### 執行前
```
test_replicate/
├── test1.txt (內容: "old1")
├── test2.txt (內容: "old2")
└── subdir1/
    ├── file1.txt (內容: "old_sub")
    └── subdir2/
        └── file2.txt (內容: "old_sub2")
```

### source.txt
```
paul says hello to you
```

### 執行後
```
test_replicate/
├── test1.txt (內容: "paul says hello to you")
├── test2.txt (內容: "paul says hello to you")
└── subdir1/
    ├── file1.txt (內容: "paul says hello to you")
    └── subdir2/
        └── file2.txt (內容: "paul says hello to you")
```

## 注意事項

1. 此程式會覆蓋目標目錄中所有文件的內容
2. 源文件大小限制為 4096 字節 (buffer 大小)
3. 僅支持 32-bit x86 Linux 系統
4. 需要對目標目錄有讀寫權限

## 技術細節

### 遞歸實現
每次調用 process_directory 時，在堆棧上分配 9232 字節:
- 8192 字節用於 dir_buffer (存儲目錄項)
- 1024 字節用於 file_path (構建完整路徑)

這樣避免了全局緩衝區被遞歸調用覆蓋的問題。

### 性能考量
- 使用堆棧分配而非堆分配，速度更快
- 一次性讀取源文件到緩衝區，避免重複 I/O
- 使用 getdents64 批量讀取目錄項，減少系統調用次數

## 除錯技巧

使用 strace 追蹤系統調用:
```bash
strace -e trace=open,read,write,close,getdents64 ./replicate
```

查看文件描述符和返回值:
```bash
strace ./replicate 2>&1 | grep -E "(open|read|write)"
```

## 學習資源
- x86 Assembly Guide: https://www.cs.virginia.edu/~evans/cs216/guides/x86.html
- NASM Documentation: https://www.nasm.us/xdoc/2.15.05/html/nasmdoc0.html

