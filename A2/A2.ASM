[GLOBAL mystart]                ; Import start code.
[EXTERN _rand]                  ; Import the random function.
[EXTERN _srand]                 ; Import random seed func.

[SECTION .data]
svgaMode        equ 4F02h
vidMode         equ 4105h       ; 4 is there to specify linear addressing.
XRES            equ 1024        ; X resolution of the screen.
YRES            equ 720         ; Y resolution of the screen.

FIELD_X         equ 352         ; Position of the playing field.
FIELD_Y         equ 20          ; ""
FIELD_W         equ 10          ; Size of the playing field in brick cells.
FIELD_H         equ 20          ; ""

BORDER_W        equ 5           ; Set the width of the border.
SQR_SIZE        equ 32          ; Size of a brick.
RECT_S          equ SQR_SIZE-1  ; Size of a brick to draw. (1 pixel between).

; Collision data
FIELD_BOT       equ FIELD_Y + (FIELD_H * SQR_SIZE) + BORDER_W
FIELD_RIGHT     equ FIELD_X + (FIELD_W * SQR_SIZE) + BORDER_W

BLOCK_X         equ FIELD_X + ((FIELD_W/2-2)*SQR_SIZE) + BORDER_W ; Starting x for block.
BLOCK_Y         equ FIELD_Y + BORDER_W           ; Starting y for block.

L_BLUE          equ 9           ; Light blue.
D_BLUE          equ 1           ; Dark blue.
L_GREEN         equ 0xA         ; Light green.
PURPLE          equ 5           ; Purple.
GREY            equ 8           ; Grey
BLACK           equ 0           ; Black
ORANGE          equ 6           ; Orange
L_RED           equ 0xC         ; Light red.
YELLOW          equ 0xE         ; Yellow

; Block definitions (4x4 arrays)
; e.g.
; 0010
; 1110 J block
; 0000
; 0000
IBLOCK          db 1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
JBLOCK          db 1,1,1,0,0,0,1,0,0,0,0,0,0,0,0,0
SBLOCK          db 0,1,1,0,1,1,0,0,0,0,0,0,0,0,0,0
TBLOCK          db 0,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0
LBLOCK          db 0,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0
OBLOCK          db 1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0
ZBLOCK          db 1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0
; Array containing the addresses of all blocks. For easy reference from rand
; number generation.
BLOCKS          dd IBLOCK,JBLOCK,LBLOCK,OBLOCK,SBLOCK,TBLOCK,ZBLOCK
COLORS          dd L_BLUE,D_BLUE,ORANGE,YELLOW,L_GREEN,PURPLE,L_RED

; Seed for the random number generator.
RAND_SEED       dd 0xBEEFCA5E

[SECTION .bss]
vidmode         resb 1
curBlock        resb 16         ; Reserve 16 bytes to store the current block in.
curBlockType    resb 1          ; 0=I, 1=J, 2=L, 3=O, 4=S, 5=T, 6=Z
curBlockColor   resd 1          ; Reserve a double for the color.
curX            resd 1          ; Current x position.
curY            resd 1          ; Current y position.

[SECTION .text]
mystart:
        call    setSVGAMode     ; Set the SVGA drawing mode.

        call    drawBorder      ; Draw the border around the field.

        push    dword [RAND_SEED]       ; Set the seed.
        call    _srand                  ; Call srand. Set a seed for random.
        add     esp, 4                  ; Align the stack pointer.
        call    newBlock        
.dloop:
        .delay:
        ; Temporary delay loop.
        push    ecx
        mov     ecx, 40000000
        .iLoop:
        loop    .iLoop
        pop     ecx
        
        push    dword curBlock
        push    dword SQR_SIZE
        call    translateDown
        cmp     dword [curY], FIELD_BOT-SQR_SIZE
        jl      .finLoop
        call    newBlock
        .finLoop:

        loop    .dloop

        call    restoreMode     ; Restore the video mode.
        ret

; collDown(buffer)
; Checks to see if a block buffer will collide if it moves down.
; Input:        buffer: The buffer the block is stored in
; Output:       1 in al if it will collide; 0 otherwise.
collDown:
        enter   0,0                     ; Create stack frame
        push    ebx                     ; Save registers
        push    ecx
        push    edx
        push    edi
        push    esi
        mov     dword ebx, [ebp+8]      ; Move the buffer into edi
        mov     esi, [curY]             ; Get current Y position of block
        add     esi, SQR_SIZE           ; Move down a block
        add     esi, 2                  ; Move down a couple pixels to avoid black edges
        mov     eax, XRES               ; X-resolution of the screen in eax
        mul     esi                     ; Point to first row
        mov     esi, eax                ; Move out of accumulator
        add     esi, [curX]             ; Offset to current block
        add     esi, 2                  ; Offset to avoid black edge
        mov     edi, 16                 ; Set edi as counter
        .collLoop:
        mov     ecx, 4                  ; Set loop counter
        .inLoop:
        cmp     byte [ebx], 0           ; Check if there should be a block for current block
        je      .inEnd                  ; Skip rest if there isn't
        cmp     byte [es:esi], 0        ; Check if there is a frozen block
        je      .inEnd                  ; Skip rest if there isn't
        mov     al, 1                   ; Move 1 into al (collision found)
        jmp     .end                    ; Exit loop
        .inEnd:
        add     esi, SQR_SIZE           ; Move to next square
        inc     ebx                     ; Move to next buffer location
        add     esi, SQR_SIZE           ; Move to next block
        dec     edi                     ; Decrement buffer counter
        loop    .inLoop
        sub     esi, SQR_SIZE*4         ; Move back to start of row
        add     esi, XRES*SQR_SIZE      ; Move to next row of blocks
        cmp     edi, 1                  ; Check how many buffer locations have been checked
        jg     .collLoop                ; Jump if not at end of buffer
        mov     al, 0                   ; Set al to 0 (no collision)
        .end:
        pop     esi                     ; Restore registers
        pop     edi
        pop     edx
        pop     ecx
        pop     ebx
        leave                           ; Destroy stack frame
        ret 4                           ; 1 argument
        
; translateDown(amount, buffer)
; Translates a block represented by a 4x4 buffer downwards by n.
; Input:        amount: The amount to translate down by.
;               buffer: The buffer in which the block is represented.
; Output:
;               The block is moved n pixels down.
translateDown:
        enter   0, 0            ; Enter the function
        pushad                  ; Push the registers on to the stack.

        mov     eax, [curY]     ; Get the current y position.
        mov     ebx, [curX]     ; Get the current x position.
        mov     edx, [ebp+12]   ; Get the buffer.

        push    dword BLACK     ; Draw black.
        push    edx             ; Push the current block.
        push    eax             ; Push the y position.
        push    ebx             ; Push the x position.
        call    drawBlock       ; Draw black over the previous shape.

        push    eax
        push    edx
        call    collDown        ; Check if there will be a collision
        cmp     al, 1           ; Check if there was a collision
        je      .coll
        pop     eax
        add     eax, [ebp+8]    ; Add the offset if there was no collision
        jmp     .draw
        .coll:
        pop     eax
        mov     cl, 1           ; Set flag to reset block at end
        .draw:
        push    dword [curBlockColor]       ; Push the color.
        push    edx             ; Push the block.
        push    eax             ; Push the y position
        push    ebx             ; Push the x position.
        call    drawBlock       ; Draw the block.

        mov     [curY], eax     ; Store curY again.

        cmp     cl, 1
        jne     .end
        call    newBlock
        .end:
        popad                   ; Restore registers.
        leave                   ; Destroy the frame.
        ret     8               ; Return to caller. Stack offset 8.

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

; drawBlock(x, y, buffer, color)
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

; drawL(x, y)
; Draws an L block at the given location.
; Input:        x: x coordinate of the upper left corner of the shape
;               y: y coordinate "                                   "
; Output:       L block drawn on screen
drawL:
        enter   0,0

        push    dword ORANGE    ; Set color to orange.
        push    dword LBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.

        leave
        ret     8
        
; drawO(x, y)
; Draws an O block at the given location.
; Input:        x: x coordinate of the upper left corner of the shape
;               y: y coordinate "                                   "
; Output:       O block drawn on screen
drawO:
        enter   0,0

        push    dword YELLOW    ; Set color to yellow
        push    dword OBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.

        leave
        ret     8

; drawZ(x, y)
; Draws a Z block at the given location.
; Input:        x: x coordinate of the upper left corner of the shape
;               y: y coordinate "                                   "
; Output:       Z block drawn on screen
drawZ:
        enter   0,0

        push    dword L_RED     ; Set color to red.
        push    dword ZBLOCK    ; Set buffer.
        push    dword [ebp+12]  ; Set y coordinate
        push    dword [ebp+8]   ; Set x coorindate
        call    drawBlock      ; Draw the buffer.

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
        shl     eax, 10         ; Shift 10 left (mult by 1024)
        add     eax, [ebp+8]    ; Add the x coordinate.

        mov     edi, eax        ; Store offset in edi.
        mov     al, [ebp+16]    ; Store the color in al.
        stosb                   ; Store the pixel in es:edi

        pop     edi             ; Restore dest index.
        pop     ebx             ; Restore ebx.
        leave                   ; Restore the stack frame
        ret     12              ; Return, 12 byte offset.

; drawBorder()
; Draws the outer frame for the game on the screen.
; Output:       Draws a box on the screen
drawBorder:
        ; Draw outer rectangle.
        push    dword GREY      ; Color is gray
        push    dword FIELD_H * SQR_SIZE + (BORDER_W*2) ; Calculate the field size.
        push    dword FIELD_W * SQR_SIZE + (BORDER_W*2)
        push    dword FIELD_Y   ; Upper left y coord
        push    dword FIELD_X   ; Upper left x coord
        call    drawRect        ; Draw outer rectangle
        ; Clear inner rectangle.
        push    dword BLACK     ; Color is black
        ; Push on the size of the field.
        push    dword FIELD_H * SQR_SIZE
        push    dword FIELD_W * SQR_SIZE
        push    dword FIELD_Y+BORDER_W ; Upper left y coord
        push    dword FIELD_X+BORDER_W ; Upper left x coord
        call    drawRect        ; Draw outer rectangle
        ret
        
; random()
; Returns a random number from 0 to 6 in eax
random:
        call    _rand                   ; Generate a random number in eax
        and     eax, 7                  ; Discard all but 0111b

        cmp     eax, 7                  ; Check if random number was 7.
        jge     random                  ; If it is, loop back and generate again.

        ret                             ; Return to calling code.

; newBlock()
; Clears out the old block and replaces it with a new one
; Output:       curBlockColor, curBlockType, and curBlock all modified.
newBlock:
        enter   0,0
        pushad
        mov     dword [curBlock], 0     ; Clears out current block buffer
        mov     dword [curBlock+4], 0

        call    random                  ; Number from 0-6 in eax
        mov     [curBlockType], al      ; Move random number into block type
        mov     ebx, 4
        mul     ebx                     ; Multiply random number by 4 for offset
        mov     ebx, BLOCKS             ; Move address of block presets into ebx
        add     ebx, eax                ; Offset to block address
        add     eax, COLORS             ; Gets offset to proper colour
        mov     eax, [eax]              ; Get colour
        mov     [curBlockColor], eax    ; Stores colour
        push    dword [ebx]             ; Push block address
        push    dword curBlock          ; Push offset to block buffer
        call    copyBlock               ; Copies preset block to current block buffer
        mov     [curY], dword BLOCK_Y
        mov     [curX], dword BLOCK_X
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

; copyBlock(dest, src)
; Copies the content of one block array to another. 4x4 arrays!
; Input         dest: The location of the destination array.
;                src: The location of the source array.
; Output        dest contains the data in src.
copyBlock:
        enter   0, 0            ; Setup the frame.
        push    esi             ; Store esi and edi.
        push    edi
        push    ecx

        mov     esi, [ebp+12]   ; Set the source.
        mov     edi, [ebp+8]    ; Set the dest.
        mov     dword ecx, [esi]
        mov     dword [edi], ecx
        mov     dword ecx, [esi+4]
        mov     dword [edi+4], ecx
        mov     dword ecx, [esi+8]
        mov     dword [edi+8], ecx
        mov     dword ecx, [esi+12]
        mov     dword [edi+12], ecx

        pop     ecx
        pop     edi             ; Restore esi and edi.
        pop     esi
        leave                   ; Destroy the frame
        ret     8               ; Return to calling code
