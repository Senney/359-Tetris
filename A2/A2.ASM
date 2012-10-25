[GLOBAL mystart]                ; Import start code.
[EXTERN _random]                ; Import the random function.

[SECTION .data]
svgaMode        equ 4F02h
vidMode         equ 4105h       ; 4 is there to specify linear addressing.
XRES            equ 1024        ; X resolution of the screen.
YRES            equ 720         ; Y resolution of the screen.

FIELD_X         equ 250         ; Position of the playing field.
FIELD_Y         equ 100         ; ""
FIELD_W         equ 10          ; Size of the playing field in brick cells.
FIELD_H         equ 20          ; ""
BORDER_W        equ 5           ; Set the width of the border.
SQR_SIZE        equ 32          ; Size of a brick.
RECT_S          equ SQR_SIZE-1  ; Size of a brick to draw. (1 pixel between).

BLOCK_X         equ FIELD_X + ((FIELD_W/2-2)*SQR_SIZE) + BORDER_W ; Starting x for block.
BLOCK_Y         equ FIELD_Y + BORDER_W           ; Starting y for block.

L_BLUE          equ 9           ; Light blue.
D_BLUE          equ 1           ; Dark blue.
L_GREEN         equ 0xA         ; Light green.
PURPLE          equ 5           ; Purple.
GREY            equ 8           ; Grey
BLACK           equ 0           ; Black

; Block definitions (4x4 arrays)
; e.g.
; 0010
; 1110 J block
; 0000
; 0000
IBLOCK          db 1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0
JBLOCK          db 0,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0
SBLOCK          db 0,1,1,0,1,1,0,0,0,0,0,0,0,0,0,0
TBLOCK          db 0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0
LBLOCK          db 0,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0
OBLOCK          db 1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0
ZBLOCK          db 1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0
; Array containing the addresses of all blocks. For easy reference from rand
; number generation.
BLOCKS          dd IBLOCK,JBLOCK,SBLOCK,TBLOCK,LBLOCK,OBLOCK,ZBLOCK

[SECTION .bss]
vidmode         resb 1
curBlock        resb 16         ; Reserve 16 bytes to store the current block in.


[SECTION .text]
mystart:
        call    setSVGAMode     ; Set the SVGA drawing mode.

        call    drawBorder      ; Draw the border around the field.

        push    dword 16        ; Size of array.
        push    dword curBlock  ; curBlock array.
        push    dword IBLOCK    ; Replace with address of block.
        call    copyArray       ; Copy the array.

        call    readChar        ; Read a character from the buffer.

        call    restoreMode     ; Restore the video mode.
        ret

; drawT(x, y)
; Draws a T block starting at position x, y
; Input:        x: The x coordinate.
;               y: The y coordinate.
drawT:
        enter   0, 0            ; Enter the function.

        push    dword PURPLE    ; Set color to purple
        push    dword TBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.

        leave                   ; Destroy frame.
        ret     8               ; Return to caller.

; drawS(x, y)
; Draws a S block starting at position x, y
; Input:        x: The x coordinate.
;               y: The y coordinate.
drawS:
        enter   0, 0            ; Enter the function.

        push    dword L_GREEN   ; Set color to light green
        push    dword SBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.

        leave                   ; Destroy frame.
        ret     8               ; Return to caller.        

; drawJ(x, y)
; Draws a J block starting at position x, y
; Input:        x: The x coordinate.
;               y: The y coordinate.
drawJ:
        enter   0, 0            ; Enter the function.

        push    dword D_BLUE    ; Set color to light green
        push    dword JBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.

        leave                   ; Destroy frame.
        ret     8               ; Return to caller.

; drawI(x, y)
; Draws an I block starting at position x, y
; Input:        x: The x coordinate.
;               y: The y coordinate.
drawI:
        enter   0, 0            ; Enter the function.

        push    dword L_BLUE    ; Set color to light green
        push    dword IBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.
        
        leave                   ; Destroy stack frame.
        ret     8               ; Return to caller.

; drawBlock(x, y, xs, ys, buffer)
; Draws a block at the specified coordinates (x, y) from the buffer.
; Input:        x: x coord.
;               y: y coord.
;          buffer: the buffer in which the block is stored.
;           color: the color of the block
drawBlock:
        enter   0, 0            ; Enter the function.
        pushad                  ; Save registers.

        mov     esi, [ebp+16]   ; Set the buffer.
        mov     ebx, [ebp+12]   ; Get the y position.
        mov     edx, 0          ; Clear the y counter
.outLoop:
        mov     ecx, 4          ; Set loop counter
        mov     eax, [ebp+8]    ; Set the x value.
.inLoop:
        cmp     [esi], byte 0   ; Check if we need to draw a block.
        je      .inEnd          ; End this iteration if we don't

        push    eax             ; Save eax.
        push    dword [ebp+20]  ; Get color from buffer
        push    dword RECT_S    ; Height
        push    dword RECT_S    ; Width
        push    ebx             ; y coord.
        push    eax             ; x coord
        call    drawRect        ; Draw the rectangle.
        pop     eax             ; Restore eax.
.inEnd
        add     eax, RECT_S+1   ; Add to the x counter
        inc     esi             ; Increment the buffer spot
        loop    .inLoop         ; Loop back and go again
        inc     edx             ; Increment the y counter
        add     ebx, RECT_S+1   ; Add to the y counter
        cmp     edx, 4          ; check if we're done looping
        jne     .outLoop        ; If not, go loop again.

        popad                   ; Restore registers.
        leave                   ; Destroy frame.
        ret     16              ; Offset stack by 12, return to caller.
        
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
        shl     eax, 10         ; Shift 10 left (mult by 1024)
        add     eax, [ebp+8]    ; Add the x coordinate.

        mov     edi, eax        ; Store offset in edi.
        mov     al, [ebp+16]    ; Store the color in al.
        stosb                   ; Store the pixel in es:edi

        pop     edi             ; Restore dest index.
        pop     ebx             ; Restore ebx.
        leave                   ; Restore the stack frame
        ret     12              ; Return, 12 byte offset.

; Draws the outer box for the game on the screen.
; Output:       Draws a box on the screen
drawBorder:
        ; Draw outer rectangle.
        push    dword GREY      ; Color is gray
        push    dword FIELD_H * SQR_SIZE        ; Calculate the field size.
        push    dword FIELD_W * SQR_SIZE
        push    dword FIELD_Y   ; Upper left y coord
        push    dword FIELD_X   ; Upper left x coord
        call    drawRect        ; Draw outer rectangle
        ; Clear inner rectangle.
        push    dword BLACK     ; Color is black
        ; Push on the size of the field.
        push    dword FIELD_H * SQR_SIZE-(BORDER_W*2)
        push    dword FIELD_W * SQR_SIZE-(BORDER_W*2)
        push    dword FIELD_Y+BORDER_W ; Upper left y coord
        push    dword FIELD_X+BORDER_W ; Upper left x coord
        call    drawRect        ; Draw outer rectangle
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

; copyArray(dest, src, size)
; Copies the content of one array to another.
; Input         dest: The location of the destination array.
;                src: The location of the source array.
;               size: The size of the source array and dest array.
; Output        dest contains the data in src.
copyArray:
        enter   0, 0            ; Setup the frame.

        mov     esi, [ebp+12]   ; Set the source.
        mov     edi, [ebp+8]    ; Set the dest.
        mov     ecx, [ebp+16]   ; Set the amount of data to copy.
        rep     movsb           ; Move data from esi to edi.

        leave                   ; Destroy the frame
        ret     12              ; Return to calling code
