; Assignment 2 - Tetris
; Participants
;       Sean Heintz - 10053525
;       Brent Glowinski - 10060894
; Notes
;       Instead of using the 7 procedures, we used a more efficient method
;       involving creating an array that points to arrays that define each 
;       block. The data in these arrays are then copied into a matrix that
;       contains the current block. This buffer is then used for all 'local'
;       changes to the block.
;       An email to Setareh confirmed that this method was acceptable.        


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

BORDER_W        equ 31           ; Set the width of the border.
SQR_SIZE        equ 32          ; Size of a brick.
RECT_S          equ SQR_SIZE-1  ; Size of a brick to draw. (1 pixel between).

; Collision data
; Defining the mathematical boundaries of the playing field.
FIELD_TOP       equ FIELD_Y + BORDER_W
FIELD_BOT       equ FIELD_Y + (FIELD_H * SQR_SIZE) + BORDER_W
FIELD_RIGHT     equ FIELD_X + (FIELD_W * SQR_SIZE) + BORDER_W
FIELD_LEFT      equ FIELD_X + BORDER_W

; The starting place for the block.
BLOCK_X         equ FIELD_X + ((FIELD_W/2-2)*SQR_SIZE) + SQR_SIZE + BORDER_W ; Starting x for block.
BLOCK_Y         equ FIELD_Y + BORDER_W  ; Starting y for block.
; The block starts above the field so that it can be drawn.

L_BLUE          equ 9           ; Light blue.
D_BLUE          equ 1           ; Dark blue.
L_GREEN         equ 0xA         ; Light green.
PURPLE          equ 5           ; Purple.
GREY            equ 8           ; Grey
BLACK           equ 0           ; Black
ORANGE          equ 6           ; Orange
L_RED           equ 0xC         ; Light red.
YELLOW          equ 0xE         ; Yellow
FROZEN          equ 0xF         ; Light purple for frozen blocks.

; Block definitions (4x4 arrays)
; e.g.
; 0010
; 1110 J block
; 0000
; 0000
IBLOCK          db 0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0
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
RAND_SEED       dd 0xB33FC453

; Number of iterations for the delay.
DELAY_NORMAL    equ 40000000    ; Normal delay for quick drop blocks.
DELAY_FAST      equ 20000000    ; Fast delay for quick drop blocks (2x fast).
DELAYAMOUNT     dd  DELAY_NORMAL; The amount to actually delay.

[SECTION .bss]
vidmode         resb 1          ; Storage for the previous video mode.
curBlock        resb 16         ; Reserve 16 bytes to store the current block in.
tempBlock       resb 16         ; Temporary storage for 16 bytes for block rotation.
curBlockType    resb 1          ; 0=I, 1=J, 2=L, 3=O, 4=S, 5=T, 6=Z
curBlockColor   resd 1          ; Reserve a double for the color.
curX            resd 1          ; Current x position.
curY            resd 1          ; Current y position.
hasTranslated   resb 1          ; Byte to indicate whether the current block has moved yet.
atTop           resb 1          ; Flag for if we have gotten to the top yet.

oldHandler      resw 1          ; Storage for old handler pointer.
oldHandleroff   resd 1          ; old handler offset.
raw_key         resb 1          ; Storage for the keypress.
endData         resb 1          ; Marker for end of data section

[SECTION .text]

; mystart
; Entry position for the code.
mystart:
        call    setSVGAMode             ; Set the SVGA drawing mode.

        call    drawBorder              ; Draw the border around the field.

        push    dword [RAND_SEED]       ; Set the seed.
        call    _srand                  ; Call srand. Set a seed for random.
        add     esp, 4                  ; Align the stack pointer.
        call    newBlock        
          
        call    kb_initialize           ; Start the keyboard ISR.
.dloop:
        cmp     byte [atTop], 1         ; Check if we're at the top of the playing field.
        ;je      .loopDone               ; If we're at the top, finish the game.

        mov     al, [raw_key]           ; Get the raw key.
        cmp     al, 01h                 ; Compare al to escape code.
        je      near .loopDone          ; Finish the loop.
        cmp     al, 0c8h                ; Check if pressed is uparrow.
        jne     .skipRotate             ; If it isn't, skip the rotate.

        push    dword curBlock          ; Push the buffer.
        call    eraseBlock              ; Erase the block.

        push    dword curBlock          ; Push the buffer.
        call    rotateCW                ; Rotate the block.
        mov     [raw_key], byte 0       ; Clear the key.

        ; Redraw the erased block.
        push    dword [curBlockColor]   ; Push the color.
        push    dword curBlock          ; Push the block.
        push    dword [curY]            ; Push the y position
        push    dword [curX]            ; Push the x position.
        call    drawBlock               ; Draw the block.

.skipRotate:
        cmp     [raw_key], byte 50h     ; Check if down arror is... down.
        jne     .resetSpeed             ; If it's not, skip.

        mov     [DELAYAMOUNT], dword DELAY_FAST ; Set the delay time.
        jmp     .skipFast                       ; Don't reset it.
.resetSpeed:
        mov     [DELAYAMOUNT], dword DELAY_NORMAL; Set back delay.
.skipFast:
        cmp     ecx, 0                  ; Should we move the block down?
        jne     .skipDown               ; Don't move the block if the timer is not done.
        push    dword curBlock          ; Push the block that we're looking to translate.
        push    dword SQR_SIZE          ; Push the amount that we want to translate by.
        call    translateDown           ; Translate the block.
        mov     ecx, [DELAYAMOUNT]      ; Reset the loop counter.

.skipDown
        
        ; Just a hard boundary check in case something in the translation phase fails.
        ; Essentially a fail safe to prevent seg and page faults.
        cmp     dword [curY], FIELD_BOT-SQR_SIZE        
        jl      .loopDone        ; If we're in bounds, don't do anything.        
        call    newBlock        ; Otherwise, get a new block.
        
.loopDone:
        call    kb_destroy      ; Restore the old isr.

        call    restoreMode     ; Restore the video mode.
        ret

; eraseBlock(buffer)
; Erases the block in the buffer by overwriting it with block.
; Input:        buffer: The current block buffer.
; Output:       The block is erased from the screen.
eraseBlock:
        enter   0, 0

        ; Erase the old block.
        push    dword BLACK     ; Draw black.
        push    dword [ebp+8]   ; Push the current block.
        push    dword [curY]    ; Push the y position.
        push    dword [curX]    ; Push the x position.
        call    drawBlock       ; Draw black over the previous shape.        

        leave
        ret     4

; rotateCW(buffer)
; Rotates the block in the buffer 90 degrees clockwise.
; Input:        buffer: the buffer the block is stored in.
; Output:       buffer contains a 90 degree rotated block.
rotateCW:
        enter   0, 0                   ; Create stack frame. 16 bytes
                                        ; of space for array to copy new into.
        pushad                          ; Store all registers.

        mov     edi, [ebp+8]            ; Get the block buffer.

        ; Clear out the tempBlock before use.
        mov     ecx, 0                  ; Set buffer size.
.clear:
        mov     [ecx+tempBlock], byte 0 ; Clear the memory location.
        inc     ecx                     ; Increment counter
        cmp     ecx, 16                 ; Check if at end of buffer.
        jne     .clear                  ; Keep clearing.
        
        mov     eax, 0                  ; Cur y counter.
        .outLoop:
        mov     ecx, 0                  ; cur x counter.
        .inLoop:
        cmp     byte [edi], 0           ; Check if there is a block here to move.
        je      .inEnd                  ; Skip rest if there isn't
        
        ; Here we will rotate the block.
        ; xnew = y0 - yold + x0         ; x0 = 1
        ; simplify to xnew = y0 + x0 - yold
        ;             xnew = 2 - yold
        ; ynew = xold - x0 + y0         ; y0 = 1
        ; simplify to ynew = xold since -x0 + y0 = 0
        ; ebx = xnew
        ; edx = ynew

        mov     ebx, 2                  ; Set xnew to (y0 + x0)
        sub     ebx, eax                ; xnew = (y0+x0) - yold.

        ; Hack to get the 4th cell of i block working.
        cmp     ebx, 0                  ; Check if ebx < 0
        jge     .skipYHack              ; If not, skip the hack.

        mov     ebx, 3                  ; Set EBX to end of x buffer.
        mov     edx, 1                  ; Set Y value to 1.
        jmp     .finishHack             ; Finish the hack.
.skipYHack
        mov     edx, ecx                ; Set ynew = xold.

.finishHack
        shl     edx, 2                  ; Multiply ynew by 4.
        add     edx, ebx                ; Add ebx.

        mov     [edx+tempBlock], byte 1 ; Store a 1 at the location in
                                        ; temp buffer.        
        .inEnd:
        inc     edi                     ; Move to next buffer location
        inc     ecx                     ; Decrement x counter
        cmp     ecx, 4                  ; Check if x is < 0
        jne     .inLoop                 ; If not, loop back.

        inc     eax                     ; Decrement outer loop.
        cmp     eax, 4                  ; Check if we're out of rows.
        jne     .outLoop                ; If we're not, go back to the outer loop.

        ; Copy the temporary array into the current block buffer.
        push    dword tempBlock         ; Push the temporary block.
        push    dword [ebp+8]           ; Push the current block.
        call    copyBlock
        
        popad
        leave
        ret     4        
        
; collide(x, y, buffer)
; Checks to see if the given block collides with anything.
; Input:        x: x-position of the block
;               y: y-position of the block
;          buffer: Buffer containing the block shape
; Ouput:        1 in al if it will collide; 0 otherwise.
collide:
        enter   0,0                     ; Create stack frame
        push    ebx                     ; Save registers
        push    ecx
        push    edx
        push    edi
        push    esi
        mov     dword edx, [ebp+16]     ; Move the buffer into edx

        mov     dword ebx, [ebp+12]     ; Get the current Y position of the block.
        mov     dword eax, [ebp+8]      ; Current X position.

        add     ebx, 2                  ; Offset y position by 2 pixels.
        add     eax, 2                  ; Offset x position by 2 pixels.
        ; This is done so that we check the actual inside of the block
        ; instead of the black border where collision detection will fail.

        ; Setup the pixel offset in the buffer.
        mov     esi, ebx                ; Move the Y position into edi for manipulation.
        shl     esi, 10                 ; Multiply by 1024
        add     esi, eax                ; Add the x coordinate.

        mov     eax, 4                  ; Number of rows in the matrix.

        .collLoop:
        mov     ecx, 4                  ; Columns in matrix.
        .inLoop:
        cmp     byte [edx], 0           ; Check if there should be a block for current block
        je      .inEnd                  ; Skip rest if there isn't
        cmp     byte [es:esi], 0        ; Check if it's the frozen color.
        je      .inEnd
        .collision:
        mov     al, 1                   ; Move 1 into al (collision found)
        jmp     .end                    ; Exit loop
        .inEnd:
        add     esi, SQR_SIZE           ; Move to next square
        inc     edx                     ; Move to next buffer location
        loop    .inLoop                 ; Loop back and check more pixels.
        
        sub     esi, SQR_SIZE * 4       ; Bring pointer back to beginning of row.
        add     esi, XRES*SQR_SIZE      ; Move to next row of blocks.
        add     ebx, SQR_SIZE           ; Increase Y position for collision.

        dec     eax                     ; Decrement the outer loop counter.
        cmp     eax, 0                  ; Check if we still need to loop.
        jne     .collLoop               ; Loop back if we do.

        .noCollision:
        mov     al, 0                   ; Set al to 0 (no collision)
        .end:
        pop     esi                     ; Restore registers
        pop     edi
        pop     edx
        pop     ecx
        pop     ebx

        leave                           ; Destroy stack frame
        ret     12                      ; Return, 3 arguments

; collDown(buffer)
; Checks to see if a block buffer will collide if it moves down.
; Input:        buffer: The buffer the block is stored in
; Output:       1 in al if it will collide; 0 otherwise.
collDown:
        enter   0,0                     ; Create stack frame
        push    ebx                     ; Save ebx

        push    dword [ebp+8]           ; Push buffer
        mov     ebx, [curY]             ; Get current y position
        add     ebx, SQR_SIZE           ; Add for position of the next block down
        push    dword ebx               ; Push next y position
        push    dword [curX]            ; Push current x position
        call    collide                 ; Checks to see if next block down collides
        ; al set based on whether or not there was a collision

        pop     ebx                     ; Restore ebx
        leave                           ; Destroy stack frame
        ret 4                           ; 1 argument

; collLeft(buffer)
; Checks to see if a block buffer will collide if it moves left.
; Input:        buffer: The buffer the block is stored in
; Output:       1 in al if it will collide; 0 otherwise.
collLeft:
        enter   0,0                     ; Create stack frame
        push    ebx                     ; Save ebx

        push    dword [ebp+8]           ; Push buffer
        push    dword [curY]            ; Push current y position
        mov     dword ebx, [curX]       ; Get current x position
        sub     ebx, SQR_SIZE           ; Subtract one block to check to the left
        push    dword ebx               ; Push modified x position
        call    collide                 ; Checks to see if next block to the left collides
        ; al set based on whether or not there was a collision

        pop     ebx                     ; Restore ebx
        leave                           ; Destroy stack frame
        ret 4                           ; 1 argument

; collRight(buffer)
; Checks to see if a block buffer will collide if it moves right.
; Input:        buffer: The buffer the block is stored in
; Output:       1 in al if it will collide; 0 otherwise.
collRight:
        enter   0,0                     ; Create stack frame
        push    ebx                     ; Save ebx

        push    dword [ebp+8]           ; Push buffer
        push    dword [curY]            ; Push current y position
        mov     dword ebx, [curX]       ; Get current x position
        add     ebx, SQR_SIZE           ; Add one block to check to the right
        push    dword ebx               ; Push modified x position
        call    collide                 ; Checks to see if next block to the left collides
        ; al set based on whether or not there was a collision

        pop     ebx                     ; Restore ebx
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
        
        ; The idea here is to erase the previous block, and then check for collision.
        ; This allows us to check everything entirely on the lfb instead of making use of
        ; other buffers.
        
        ; Erase the old block.
        push    dword BLACK     ; Draw black.
        push    edx             ; Push the current block.
        push    eax             ; Push the y position.
        push    ebx             ; Push the x position.
        call    drawBlock       ; Draw black over the previous shape.

        push    eax             ; Save the current y position (not for function).
        
        ; Collision detection.
        push    edx             ; Push in the buffer that we're translating.
        call    collDown        ; Check if there will be a collision
        cmp     al, 1           ; Check if there was a collision
        je      .coll           ; If there was, handle it.
                                
        pop     eax             ; Restore the y position.
        add     eax, [ebp+8]    ; Add the offset if there was no collision
        jmp     .draw           ; Continue with the drawing process.
        
        .coll:
        pop     eax             ; Restore the y position.
        mov     cl, 1           ; Set flag to indicate that a new block must be generasted at the end.
        cmp     [hasTranslated], byte 1 ; Check if the block has translated yet.
        je      .draw           ; If we have translated, continue drawing.
        mov     [atTop], byte 1 ; Otherwise, we must be at the top of the field, so set the flag to 1.
        .draw:
        
        ; Draw the new block after collision detection and translation.
        push    dword [curBlockColor]   ; Push the color.
        push    edx                     ; Push the block.
        push    eax                     ; Push the y position
        push    ebx                     ; Push the x position.
        call    drawBlock               ; Draw the block.

        mov     [curY], eax             ; Store curY again.

        mov     [hasTranslated], byte 1 ; Set the translation flag.
        cmp     cl, 1                   ; If the new block flag is set, we must generate a new block.
        jne     .end                    ; Otherwise, we exit the function.
        mov     [hasTranslated], byte 0 ; Clear the translation flag.
        call    newBlock
        .end:
        popad                           ; Restore registers.
        leave                           ; Destroy the frame.
        ret     8                       ; Return to caller. Stack offset 8.

; translateLeft(amount, buffer)
; Translates a block represented by a 4x4 buffer to the left by n.
; Input:        amount: The amount to translate left by.
;               buffer: The buffer in which the block is represented.
; Output:
;               The block is moved n pixels left.
translateLeft:
        enter   0, 0            ; Enter the function
        pushad                  ; Push the registers on to the stack.

        mov     eax, [curY]     ; Get the current y position.
        mov     ebx, [curX]     ; Get the current x position.
        mov     edx, [ebp+12]   ; Get the buffer.
        
        ; The idea here is to erase the previous block, and then check for collision.
        ; This allows us to check everything entirely on the lfb instead of making use of
        ; other buffers.
        
        ; Erase the old block.
        push    dword BLACK     ; Draw black.
        push    edx             ; Push the current block.
        push    eax             ; Push the y position.
        push    ebx             ; Push the x position.
        call    drawBlock       ; Draw black over the previous shape.

        push    eax
        push    ebx             ; Save the current x position (not for function).
        
        ; Collision detection.
        push    edx             ; Push in the buffer that we're translating.
        call    collLeft        ; Check if there will be a collision
        cmp     al, 1           ; Check if there was a collision
        je      .coll           ; If there was, handle it.
                                
        pop     ebx             ; Restore the x position.
        sub     ebx, [ebp+8]    ; Add the offset if there was no collision
        jmp     .draw           ; Continue with the drawing process.
        
        .coll:
        pop     ebx             ; Restore the x position.
        .draw:
        pop     eax
        ; Draw the new block after collision detection and translation.
        push    dword [curBlockColor]   ; Push the color.
        push    edx                     ; Push the block.
        push    eax                     ; Push the y position
        push    ebx                     ; Push the x position.
        call    drawBlock               ; Draw the block.

        mov     [curX], ebx             ; Store curX again.

        .end:
        popad                           ; Restore registers.
        leave                           ; Destroy the frame.
        ret     8                       ; Return to caller. Stack offset 8.

; translateRight(amount, buffer)
; Translates a block represented by a 4x4 buffer to the right by n.
; Input:        amount: The amount to translate right by.
;               buffer: The buffer in which the block is represented.
; Output:
;               The block is moved n pixels right.
translateRight:
        enter   0, 0            ; Enter the function
        pushad                  ; Push the registers on to the stack.

        mov     eax, [curY]     ; Get the current y position.
        mov     ebx, [curX]     ; Get the current x position.
        mov     edx, [ebp+12]   ; Get the buffer.
        
        ; The idea here is to erase the previous block, and then check for collision.
        ; This allows us to check everything entirely on the lfb instead of making use of
        ; other buffers.
        
        ; Erase the old block.
        push    dword BLACK     ; Draw black.
        push    edx             ; Push the current block.
        push    eax             ; Push the y position.
        push    ebx             ; Push the x position.
        call    drawBlock       ; Draw black over the previous shape.
        push    eax
        push    ebx             ; Save the current x position (not for function).
        
        ; Collision detection.
        push    edx             ; Push in the buffer that we're translating.
        call    collRight       ; Check if there will be a collision
        cmp     al, 1           ; Check if there was a collision
        je      .coll           ; If there was, handle it.
                                
        pop     ebx             ; Restore the x position.
        add     ebx, [ebp+8]    ; Add the offset if there was no collision
        jmp     .draw           ; Continue with the drawing process.
        
        .coll:
        pop     ebx             ; Restore the x position.
        .draw:
        pop     eax
        ; Draw the new block after collision detection and translation.
        push    dword [curBlockColor]   ; Push the color.
        push    edx                     ; Push the block.
        push    eax                     ; Push the y position
        push    ebx                     ; Push the x position.
        call    drawBlock               ; Draw the block.

        mov     [curX], ebx             ; Store curX again.

        .end:
        popad                           ; Restore registers.
        leave                           ; Destroy the frame.
        ret     8                       ; Return to caller. Stack offset 8.
        
; delay(amount)
; Runs a loop to delay the program for some number of iterations.
; Input:        amount: The number of iterations to delay for. Larger = More delay.
delay:
        enter   0, 0                    ; Create the stack frame.
        push    ecx                     ; Store ecx.

        mov     ecx, dword [ebp+8]      ; Get the delay amount.
.dloop:
        loop    .dloop                  ; Loop until ecx is 0.

        pop     ecx                     ; Restore ecx.
        leave                           ; Destroy frame.
        ret     4                       ; Return to caller. Offset 4.


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
        ret     16              ; Offset stack by 16, return to caller.
   
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
        push    eax             ; Push the y value.

        ; Calculate x value.
        mov     eax, [ebp + 8]  ; Set eax to x value
        add     eax, ebx        ; Add ebx to eax..
        push    eax             ; Push the x value.
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
        ret                     ; Return to calling code.
        
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
        mov     [curY], dword BLOCK_Y   ; Set the x and y positions of the blocks.
        mov     [curX], dword BLOCK_X

        ; Draw the block initially so that we dont miss the first iteration.
        push    dword [curBlockColor]   ; Push the color.
        push    dword curBlock          ; Push the buffer.
        push    dword [curY]            ; Push the Y pos.
        push    dword [curX]            ; Push the X pos.
        call    drawBlock               ; Draw the block.

        popad                           ; Restore the saved registers.
        leave                           ; Destroy the frame.
        ret                             ; Return to caller.

; checkLine()
; Checks to see if a line has been filled on the game field.
; Input:        none
; Output:       Lines are cleared if they are full.
;               Lines above are moved to appropriate places.
;               Score is increased if line is cleared.
checkLine:
        enter   0,0             ; Create stack frame
        pushad                  ; Store all registers

        mov     ecx, 0          ; Clear out ecx

        .outer:
        mov     edx, FIELD_BOT + FIELD_RIGHT + 1  ; Move position of bottom corner into edx
        mov     eax, SQR_SIZE   ; Move size of squares into accumulator
        mul     ecx             ; Multiply by current row
        mov     ebx, XRES       ; Get screen size
        mul     ebx             ; Multiply by screen size (gets to actual row)
        sub     edx, eax        ; Subtract to get current row position on screen
        add     edx, 1          ; Move to edge of block
        mov     ebx, 0          ; Clear out ebx
        .inner:
        cmp     byte [es:edx], 0; Check to see if there is a block at current location
        je      .endinner       ; If not, jump to end

        cmp     ebx, FIELD_W    ; Compare to max columns
        jl      .inner          ; Jump to top of inner loop until all columns have been examined
        push    ecx             ; Push current row
        call    deleteLine      ; Delete current line
        dec     ecx             ; Decrement current row (to check again with row previously above)
        .endinner:
        inc     ecx             ; Increment ecx to next row
        .endouter:
        cmp     ecx, FIELD_H    ; Compare to max rows
        jl      .outer          ; Jump to top until all rows have been examined.

        popad                   ; Restore all registers
        leave                   ; Destroy stack frame
        ret                     ; Return to caller

; deleteLine(row)
; Deletes the given row from the playing field and shifts all other lines down
; Input:    row: The row to be deleted from the playfield.
; Output:        Given row is deleted.
;                Rows above are moved down.
deleteLine:
        enter   0,0
        pushad

        popad
        leave
        ret     4

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
        
; KEYBOARD HANDLING
; Access raw_key for current key code from the keyboard ISR.

; kb_clearKey
; Clears a key value to 0.
kb_clearKey:
        enter   0, 0            ; Create the frame.

        mov     [raw_key], byte 0       ; Clear the key buffer.

        leave                   ; Leave frame.
        ret                     ; Return to code.

; kb_initialize()
; Sets up the new interrupt and locks relevant memory.
kb_initialize:
        enter   0, 0            ; Enter the frame.
        pushad                  ; Push all registers.

        call    lockMemory      ; Lock the memory that we use.
        call    installHandler  ; Install the handler.

        popad                   ; Restore all registers.
        leave                   ; Destroy the frame.
        ret                     ; Return to calling code.

; kb_destroy()
; Returns the old interrupt.
kb_destroy:
        enter   0, 0            ; Enter the frame.
        pushad                  ; Save all registers.

        call    removeHandler   ; Remove the old handler.

        popad                   ; Restore registers.
        leave                   ; Restore frame
        ret                     ; Return to calling code.

; newHandler()
; The new handler that we'll be using for handling keyboard input.
newHandler:
        enter   0, 0            ; Enter the frame.
        push    eax             ; Store eax.

        in      al, 60h         ; Get the value of port 60h.
        mov     [raw_key], al   ; Store the key that was grabbed.

        ; Clear PIC
        mov     al, 20h
        out     20h, al

        cmp     byte [raw_key], 4dh     ; Check if right arrow was pressed
        je      .callRight
        cmp     byte [raw_key], 4bh     ; Check if left arrow was pressed
        je      .callLeft
        cmp     byte [raw_key], 50h     ; Check if down arrow was pressed
        je      .callDown

        jmp     .end
        .callRight:
        push    dword curBlock  ; Push current block buffer
        push    dword SQR_SIZE  ; Push size of block
        call    translateRight  ; Move block to the right
        jmp     .end
        .callLeft:
        push    dword curBlock  ; Push current block buffer
        push    dword SQR_SIZE  ; Push size of block
        call    translateLeft  ; Move block to the right
        jmp     .end
        .callDown:
        push    dword curBlock  ; Push current block buffer
        push    dword SQR_SIZE  ; Push size of block
        call    translateDown  ; Move block to the right
        jmp     .end

        .end:
        pop     eax             ; Restore eax.
        leave                   ; leave the frame.
        iret                    ; Return from the interrupt.
end_newHandler:                 ; Dummy label to get the end of newHandler.

; lockMemory()
; A function to lock the memory for the old handlers code so that no paging
; issues occur.
lockMemory:
        enter   0, 0            ; Enter the frame.
        pushad                  ; Store all registers.

        ; Lock the code section.
        mov     ax, 0006h       ; Select the DPMI function.
        mov     bx, cs          ; Get segment base of cs.
        int     31h
        shl     ecx, 16
        mov     cx, dx          ; Use it to lock handler code.
        add     ecx, newHandler
        mov     ebx, ecx
        shr     ebx, 16
        mov     esi, end_newHandler - newHandler
        mov     edi, esi
        shr     esi, 16
        mov     ax, 0600h
        int     31h

        ; Lock data section.
        mov     ax, 0006h
        mov     bx, cs
        int     31h
        shl     ecx, 16
        mov     cx, dx
        add     ecx, raw_key
        mov     ebx, ecx
        shr     ebx, 16
        mov     esi, endData - raw_key  ; Get memory location of vars.
        mov     edi, esi
        shr     esi, 16
        mov     ax, 0600h       ; DPMI to lock linear region.
        int     31h

        popad                   ; Restore registers.
        leave                   ; Restore frame.
        ret                     ; Return to calling code.

; installHandler()
; Installs the keyboard handler into 09h.
installHandler:
        enter   0, 0            ; Enter the function.
        pushad                  ; Store all registers.

        ; Save the old handler.
        mov     ax, 204h        ; Use DPMI function to get current int
        mov     bl, 9h          ; Get it for int 9h.
        int     31h             ; Call the DPMI int.
        mov     [oldHandler], cx        ; Store the selector.
        mov     [oldHandleroff], ecx    ; Store the offset.

        ; Install the new one.
        mov     ax, 205h        ; Install new int.
        mov     bl, 9h          ; Install in to 9h.
        mov     cx, cs          ; Put CS as selector.
        mov     edx, newHandler ; Set the handler offset.
        int     31h             ; Call the DPMI int.

        popad                   ; Retore all registers.
        leave                   ; Restore the frame.
        ret                     ; Return to caller.

; removeHandler()
; Removes the handler that we installed.
removeHandler:
        enter   0, 0            ; Enter the frame.
        pushad                  ; Store all registers.

        mov     ax, 205h        ; Use DPMI function to set interrupt.
        mov     bl, 9h          ; Set the interrupt to use.
        mov     cx, [oldHandler] ; Set the selector.
        mov     edx, [oldHandleroff] ; Set the offset.
        int     31h             ; DPMI interrupt.

        popad                   ; Restore the registers.
        leave                   ; Restore the frame.
        ret                     ; Return to caller.
