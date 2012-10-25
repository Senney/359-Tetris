[GLOBAL mystart]                ; Import start code.
[EXTERN _rand]                  ; Import the random function.

[SECTION .data]
svgaMode        equ 4F02h
vidMode         equ 4105h       ; 4 is there to specify linear addressing.
XRES            equ 1024
YRES            equ 720

LBLOCK          db  0,0,0,0,0,6,0,0,0,6,0,0,0,6,6,0             ; yellow (orange)
OBLOCK          db  0,0,0,0,0,0Eh,0Eh,0,0,0Eh,0Eh,0,0,0,0,0     ; Light Yellow
ZBLOCK          db  0,0,0,0,0,2,2,0,2,2,0,0,0,0,0,0             ; Green

[SECTION .bss]
vidmode         resb 1
playField       resb 20*10      ; 20 rows, 10 columns
curBlock        resb 16
curBlockType    resb 1          ; 0=I, 1=J, 2=L, 3=O, 4=S, 5=T, 6=Z

[SECTION .text]
mystart:

        call    setSVGAMode     ; Set the SVGA drawing mode.
        call    drawFrame       ; Draws the outer frame on the screen
        .mainLoop:
        cmp     byte [curBlockType], 0Fh
        jne     .noBlock        ; If there is already a block, jump
        ;call    newBlock        ; Generates a new block
        .noBlock:
        push    dword 200
        push    dword 200
        call    drawL
        push    dword 400
        push    dword 200
        call    drawO
        push    dword 400
        push    dword 400
        call    drawZ
        ;jmp     .mainLoop
        call    readChar        ; Read a character from the buffer.

        call    restoreMode     ; Restore the video mode.
        ret

; drawRect(x, y, w, h, color)
; Draws a rectangle at the specified coordinates with width w and height h.
; Input:        x: The x coordinate at which to draw the rect.
;               y: The y coordinate at which to draw the rect.
;               w: The width of the rectangle.
;               h: The height of the rectangle.
;           color: The color of the rectangle.
drawRect:
        enter   0, 0
        push    ecx             ; Store ecx. Use as h counter.
        push    ebx             ; Store ebx. Use as w counter.

        mov     ecx, [ebp + 20] ; Set ecx to h value.

.rectYLoop:
        mov     ebx, [ebp + 16] ; Set ebx to w value.
.rectXLoop:
        mov     eax, [ebp + 12] ; Set eax to y value.     
        add     eax, ecx        ; Add height to y.               

        push    dword [ebp + 24]; Push the color.
        push    eax         ; Push the y value.

        ; Calculate x value.
        mov     eax, [ebp + 8]  ; Set eax to x value
        add     eax, ebx        ; Add ebx to eax..
        push    eax       ; Push the x value.
        call    drawPixel       ; Draw the pixel.

        dec     ebx             ; Decrement x.
        cmp     ebx, 0          ; Compare to 0.
        jne     .rectXLoop      ; Keep looping if not 0.
        loop    .rectYLoop      ; Otherwise, loop back to rectYLoop

        pop     ebx             ; Restore ebx.
        pop     ecx             ; Restore ecx.
        leave                   ; Destroy frame.
        ret     20              ; Offset stack by 20 bytes.

; drawL(x, y)
; Draws an L block at the given location.
; Input:        x: x coordinate of the upper left corner of the shape
;               y: y coordinate "                                   "
; Output:       L block drawn on screen
drawL:
        enter   0,0
        push    ecx
        mov     ecx, 3
        .drawloop:
        push    dword 6         ; Color orange/yellow
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y coord
        push    dword [ebp+8]   ; x coord
        call    drawRect
        add     dword [ebp+8], 30       ; Add 30 to the x-coord
        loop    .drawloop
        push    dword 6
        push    dword 29
        push    dword 29
        add     dword [ebp+12], 30      ; Move y-coord to right spot
        push    dword [ebp+12]
        sub     dword [ebp+8], 30       ; Move x-coord to right spot
        push    dword [ebp+8]
        call    drawRect
        pop     ecx
        leave
        ret     8
        
; drawO(x, y)
; Draws an O block at the given location.
; Input:        x: x coordinate of the upper left corner of the shape
;               y: y coordinate "                                   "
; Output:       O block drawn on screen
drawO:
        enter   0,0

        push    dword 0Eh       ; Colour = yellow
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect
        add     dword [ebp+8], 30       ; Move to next block coord
        push    dword 0Eh       ; Colour = yellow
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect
        add     dword [ebp+12], 30      ; Move to next block coord
        push    dword 0Eh       ; Colour = yellow
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect
        sub     dword [ebp+8], 30       ; Move to last block coord
        push    dword 0Eh       ; Colour = yellow
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect

        leave
        ret     8

; drawZ(x, y)
; Draws a Z block at the given location.
; Input:        x: x coordinate of the upper left corner of the shape
;               y: y coordinate "                                   "
; Output:       Z block drawn on screen
drawZ:
        enter   0,0

        push    dword 2         ; Colour = green
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect
        add     dword [ebp+8], 30       ; Move to next block coord
        push    dword 2         ; Colour = green
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect
        add     dword [ebp+12], 30      ; Move to next block coord
        push    dword 2         ; Colour = green
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect
        add     dword [ebp+8], 30       ; Move to last block coord
        push    dword 2         ; Colour = green
        push    dword 29        ; 29 tall
        push    dword 29        ; 29 wide
        push    dword [ebp+12]  ; y-coord
        push    dword [ebp+8]   ; x-coord
        call    drawRect

        leave
        ret     8

; drawPixel(x, y, color)
; Draws a pixel at the specified spot on the screen.
; Input:        x: The x coordinate of the pixel.
;               y: The y coordinate of the pixel.
;           color: The color of the pixel.
; Output:       Pixel is displayed on the screen.
drawPixel:
        enter   0, 0            ; Create frame.
        push    ebx             ; Push ebx.
        push    edi             ; Store dest index.

        ; Setup the pixel offset in the buffer.
        mov     eax, [ebp+12]   ; Grab the y coordinate.
        mov     ebx, XRES       ; Store the x resolution for mult.
        mul     ebx             ; Multiply!
        add     eax, [ebp+8]    ; Add the x coordinate.

        mov     edi, eax        ; Store offset in edi.
        mov     al, [ebp+16]    ; Store the color in al.
        stosb                   ; Store the pixel in es:edi

        pop     edi             ; Restore dest index.
        pop     ebx             ; Restore ebx.
        leave                   ; Restore the stack frame
        ret     12              ; Return, 12 byte offset.

; Draws the outer frame for the game on the screen.
; Output:       Draws a box on the screen
drawFrame:
        push    dword 8         ; Color is gray
        push    dword 480       ; Box is 480 pixels tall (16 rows * 20pixels/row + 10 for outer edge)
        push    dword 250       ; 250 pixels wide (10 columns * 24 pixels/col + 10 for edge)
        push    dword 160       ; Upper left y coord
        push    dword 160       ; Upper left x coord
        call    drawRect        ; Draw outer rectangle
        push    dword 0         ; Color is black
        push    dword 470       ; Inner box 470 pixels tall
        push    dword 240       ; Inner box 240 pixels wide
        push    dword 165       ; Upper left y coord
        push    dword 165       ; Upper left x coord
        call    drawRect        ; Draw inner rectangle
        ret
        
; random()
; Returns a random number from 0 to 6 in eax
random:
        call    _rand                   ; Generate a random number in eax
        and     eax, 6                  ; Gets rid of extraneous bits

; newBlock()
; Clears out the old block and gets a new one
newBlock:
        enter   0,0
        pushad
        mov     dword [curBlock], 0     ; Clears out current block buffer
        mov     dword [curBlock+4], 0
        call    random                  ; Generates a random number
        mov     byte [curBlockType], al ; Moves random block type into current type
        mov     edi, curBlock           ; Current block buffer in edi
        mov     ecx, 2                  ; Moving two doubles
        .iblock:
        ;     esi, IBLOCK             ; Address for I-block in esi
        rep     movsd                   ; Moves the I block into current buffer
        jmp     .end
        .jblock:
        cmp     eax, 1
        jne     .lblock
        ;mov     esi, JBLOCK
        rep     movsd
        jmp     .end
        .lblock:
        cmp     eax, 2
        jne     .oblock
        mov     esi, LBLOCK
        rep     movsd
        jmp     .end
        .oblock:
        cmp     eax, 3
        jne     .sblock
        mov     esi, OBLOCK
        rep     movsd
        jmp     .end
        .sblock:
        cmp     eax, 4
        jne     .tblock
        ;mov     esi, SBLOCK
        rep     movsd
        jmp     .end
        .tblock:
        cmp     eax, 5
        jne     .zblock
        ;mov     esi, TBLOCK
        rep     movsd
        jmp     .end
        .zblock:
        mov     esi, ZBLOCK
        rep     movsd
        .end:
        popad
        leave
        ret

; A function to set the videomode to SVGA so that we can start
; to draw to the screen.
setSVGAMode:
        push    ebx             ; Store ebx
        call    storeVideoMode  ; Store the previous video mode.

        mov     ax, svgaMode    ; Set the drawing mode.
        mov     bx, vidMode     ; Set the video mode. Linear 800x600 256c

        int     10h             ; Call the interrupt.

        mov     ax, fs          ; Store fs into ax.
        mov     es, ax          ; Store ax into es for use with stosb (es:edi)

        pop     ebx             ; Restore ebx.
        ret                     ; Return to caller.

; Function to restore the video mode from stored memory.
restoreMode:
        mov     eax, 0          ; Clear eax register.
        mov     al, byte [vidmode]   ; Set al to the old video mode.
        int     10h             ; Restore the video mode.
        ret                     ; Return to calling code.

; Store the current video mode into memory.
storeVideoMode:
        push    ebx             ; Store ebx
        
        mov     AH, 0Fh         ; Set interrupt code.
        int     10h             ; Call the interrupt.

        mov     [vidmode], al   ; store the video mode for later use.

        pop     ebx             ; Restore ebx.
        ret                     ; Return to calling code.

; A function to print out a string.
; Input:        edx - Memory location of string.
; Registers:    ah - Modified for Interrupt.
;               edx - The memory location of the string that is being printed
; Output:       None
print:
        mov     ah, 09h
        int     0f1h
        ret

; Reads a single character from the io.
; Input:        None
; Registers:    eax - Output
; Output:       eax - The character that was read.
readChar:
        mov     ah, 01h
        int     0f1h
        ret