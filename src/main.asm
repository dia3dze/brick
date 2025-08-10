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
PositionBallX:     ds 1
PositionBallY:     ds 1
joyState:          ds 1
GameState:         ds 1
BrickMatrix:       ds 64

SECTION "Code", ROM0[$150]

;; Start Gameloop
Ready:
        ld sp, $FFFE
        call WaitVBlank
        call ResetGameState
        DisableLCD
        call InitializeData
        call CopySpritesToVRAM
        call ClearOAM
        call LoadOAM
        EnableLCD
        InitDisplayRegisters
        ei
        jp Process

Process:
        call WaitNotVBlank
        call WaitVBlank
        call ReadInput
        call CheckGameState

        ld a, [GameState]
        cp 1
        call z, StateRunning
        ld a, [GameState]
        cp 1
        call nz, StateIdle

        call LoadOAM
        jp Process

StateIdle:
        call MovePlatform
        call BallChasePlatform
        ret

StateRunning:
        call MovePlatform
        ret

;; End Gameloop

BallChasePlatform:
        ld a, [PositionPlatformX]
        ld [PositionBallX], a
        ld a, [PositionPlatformY]
        sub 2
        ld [PositionBallY], a
        ret

CheckGameState:
        ld a, [joyState]
        bit 2, a
        call z, SetGameState
        ret

SetGameState:
        ld a, 1
        ld [GameState], a
        ret

ResetGameState:
        ld a, 0
        ld [GameState], a
        ret

MovePlatform:
        ld a, [joyState]
        bit 1, a
        jr nz, CheckRight
        call MoveLeft
        ret

CheckRight:
        bit 0, a
        call z, MoveRight
        ret


ReadInput:
        ld a, %00100000
        ld [rP1], a
        nop
        nop
        ld a, [rP1]
        and $0F
        ld [joyState], a
        ret

MoveLeft:
        ld a, [PositionPlatformX]
        sub PLATFORM_SPEED
        jr nc, .update
        ld a, SCREEN_LIMIT_LEFT
.update:
        ld [PositionPlatformX], a
        ret

MoveRight:
        ld a, [PositionPlatformX]
        add PLATFORM_SPEED
        cp SCREEN_LIMIT_RIGHT
        jr nc, .return
        ld [PositionPlatformX], a
.return:
        ret

LoadOAM:
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

        ld a, [PositionBallY]
        add OFFSET_Y
        ld [hli], a
        ld a, [PositionBallX]
        add OFFSET_X
        ld [hli], a
        ld a, 0
        ld [hli], a
        ld a, 0
        ld [hli], a

        ld de, BrickMatrix
        ld c, NUM_BRICKS

LoadOAM_Loop:
        ld a, [de]
        inc de
        add OFFSET_Y
        ld [hli], a

        ld a, [de]
        inc de
        add OFFSET_X
        ld [hli], a

        ld a, 2
        ld [hli], a

        ld a, 0
        ld [hli], a

        dec c
        jr nz, LoadOAM_Loop

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
        ld a, BALL_START_POSITION_Y
        ld [PositionBallY], a

        ld b, 64
        ld hl, BrickPositions
        ld de, BrickMatrix

        .copyLoop:
        ld a, [hl]
        ld [de], a
        inc hl
        inc de
        dec b
        jr nz, .copyLoop

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
sprite_ball:     incbin "assets/sprites/ball.bin"
sprite_platform: incbin "assets/sprites/platform.bin"
sprite_brick:    incbin "assets/sprites/brick.bin"
BrickPositions:
        db 0, 8, 0, 24, 0, 40, 0, 56, 0, 72, 0, 88, 0, 104, 0, 120, 0, 136, 0, 152
        db 16, 8, 16, 24, 16, 40, 16, 56, 16, 72, 16, 88, 16, 104, 16, 120, 16, 136, 16, 152
