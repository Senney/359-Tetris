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
        push    byte 4          ; Set the color.
        push    byte 32         ; Set the y coord
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

        ; Setup the pixel offset in the buffer.
        mov     eax, [ebp+12]   ; Grab the y coordinate.
        mov     ebp, XRES       ; Store the x resolution for mult.
        mul     ebx             ; Multiply!
        add     eax, [ebp+8]    ; Add the x coordinate.

        mov     ebx, [ebp+16]   ; Store the color for use.
        mov     [fs:eax], ebx   ; Store the color in the frame buffer.

        ret     12              ; Return, 12 byte offset.

; A function to set the videomode to SVGA so that we can start
; to draw to the screen.
setSVGAMode:
        push    ebx             ; Store ebx
        call    storeVideoMode  ; Store the previous video mode.

        mov     ax, svgaMode    ; Set the drawing mode.
        mov     bx, vidMode     ; Set the video mode. Linear 800x600 256c

        int     10h             ; Call the interrupt.

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
        
