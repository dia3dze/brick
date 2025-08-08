include "src/include/hardware.inc"
include "src/include/constants.inc"

MACRO DisableLCD
        ld a, 0
        ld [rLCDC], a
ENDM

MACRO EnableLCD
        ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
        ld [rLCDC], a
ENDM

MACRO InitDisplayRegisters
        ld a, %11011000
        ld [rBGP], a
        ld a, %11100100
        ld [rOBP0], a
ENDM

SECTION "Header", ROM0[$100]
        jp Ready
        ds $150 - @, 0  

SECTION "Data", WRAM0[$C000]

PositionPlatformX: ds 1
PositionPlatformY: ds 1
PositionBallX: ds 1
PositionBallY: ds 1

SECTION "Code", ROM0[$150]
;; Start Main

Ready:
        ld sp, $fffe
        call WaitVBlank
        DisableLCD
        call InitializeData
        call CopySpritesToVRAM
        call ClearOAM
        call ReadyOAM
        EnableLCD
        InitDisplayRegisters
        jp Process

Process:
        halt
        jp Process

;; End Main

ReadyOAM:
        ld hl, _OAMRAM
        ld a, [PositionPlatformY]
        add OFFSET_Y
        ld [hli], a
        ld a, [PositionPlatformX]
        add OFFSET_X
        ld [hli], a
        ld a, 1
        ld [hli], a
        ld a, 0
        ld [hli], a
        ret

ClearOAM:
       ld hl, _OAMRAM
       ld b, 40 * 4
.loop
       ld a, 0
       ld [hli], a
       dec b
       jp nz, .loop
       ret

InitializeData:
        ld a, PLATFORM_START_POSITION_X
        ld [PositionPlatformX], a
        ld a, PLATFORM_START_POSITION_Y
        ld [PositionPlatformY], a
        ld a, BALL_START_POSITION_X
        ld [PositionBallX], a
        ld a, BALL_START_POSITION_X
        ld [PositionBallY], a
        ret


CopySpritesToVRAM:
    ld hl, sprite_ball
    ld de, _VRAM
    ld bc, 48

.loop:
    ld a, [hl]
    ld [de], a
    inc hl
    inc de
    dec bc
    ld a, b
    or c
    jp nz, .loop
    ret
        
WaitNotVBlank:
        ld a, [rLY]
        cp SCRN_Y
        jp nc, WaitNotVBlank
        ret

WaitVBlank:
        ld a, [rLY]
        cp SCRN_Y
        jp c, WaitVBlank
        ret

SECTION "Assets", ROM0[$800]
sprite_ball: incbin "assets/sprites/ball.bin"
sprite_platform: incbin "assets/sprites/platform.bin"
sprite_brick: incbin "assets/sprites/brick.bin"
