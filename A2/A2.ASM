<<<<<<< HEAD
[GLOBAL mystart]                ; Import start code.
[EXTERN _random]                ; Import the random function.

[SECTION .data]
svgaMode        equ 4F02h
vidMode         equ 4105h       ; 4 is there to specify linear addressing.
XRES            equ 1024
YRES            equ 720

[SECTION .bss]
vidmode         resb 1

[SECTION .text]
mystart:

        call    setSVGAMode     ; Set the SVGA drawing mode.

        mov     ecx, 100        ; Draw pixels.
.drawloop:
        push    dword 4         ; Set the color.
        push    dword 32        ; Set the y coord
        push    ecx             ; Set the x coord.
        call    drawPixel       ; Draw the pixel.

        call    readChar        ; Read a character from the buffer.

        call    restoreMode     ; Restore the video mode.
        ret

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

; Draws the outer box for the game on the screen.
; Output:       Draws a box on the screen
drawBox:
        push    dword 8         ; Color is gray
        push    dword 394       ; Box is 394 pixels tall (16 rows * 24pixels/row + 10 for outer edge)
        push    dword 250       ; 250 pixels wide (10 columns * 24 pixels/col + 10 for edge)
        push    dword 160       ; Upper left y coord
        push    dword 160       ; Upper left x coord
        call    drawRect        ; Draw outer rectangle
        push    dword 0         ; Color is black
        push    dword 384       ; Inner box 384 pixels tall
        push    dword 240       ; Inner box 240 pixels wide
        push    dword 170       ; Upper left y coord
        push    dword 170       ; Upper left x coord
        call    drawRect        ; Draw inner rectangle
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
        
=======
[GLOBAL mystart]                ; Import start code.
[EXTERN _random]                ; Import the random function.

[SECTION .data]
svgaMode        equ 4F02h
vidMode         equ 4105h       ; 4 is there to specify linear addressing.
XRES            equ 1024
YRES            equ 720

[SECTION .bss]
vidmode         resb 1

[SECTION .text]
mystart:

        call    setSVGAMode     ; Set the SVGA drawing mode.

        mov     ecx, 100        ; Draw pixels.

        push    dword 4         ; Color
        push    dword 24        ; height
        push    dword 24        ; Width
        push    dword 200       ; y
        push    dword 400       ; x
        call    drawRect        ; Draw the rectangle.

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
        mov     al, [ebp + 16]  ; Store the color in al.
        stosb                   ; Store the pixel in es:edi

        pop     edi             ; REstore dest index.
        pop     ebx             ; Restore ebx.
        leave                   ; Destroy stack frame.
        ret     12              ; Return, 12 byte offset.

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
        
>>>>>>> 80a99c90c3d8e547f57314969403fc80ef4a7242
