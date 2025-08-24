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
Randi:             ds 1
BallDirectionX:    ds 1
BallDirectionY:    ds 1
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
        call MoveBall
        call BallCheckWallCollision
        call BallCheckCeilingCollision
        call BallCheckPlatformCollision
        call BallCheckDeath
        ret

;; End Gameloop

BallCheckDeath:
        ld a, [PositionBallY]
        ld b, SCREEN_LIMIT_FLOOR
        cp b
        jr nc, .die
        ret
        .die:
        ld a, 0
        ld [GameState], a
        ret

ChangeBallDirectionToUp:
        ld a, $FF
        ld [BallDirectionY], a
        ret

ChangeBallDirectionToDown:
        ld a, $01
        ld [BallDirectionY], a
        ret

ChangeBallDirectionToLeft:
        ld a, $FF
        ld [BallDirectionX], a
        ret

ChangeBallDirectionToRight:
        ld a, $01
        ld [BallDirectionX], a
        ret

BallCheckPlatformCollision:
        .checkForCollisionY:
        ld a, [PositionBallY]
        ld b, BALL_COLLISION_OFFSET_Y
        add b
        ld c, a
        ld a, [PositionPlatformY]
        ld b, PLATFORM_COLLISION_OFFSET_Y
        add b
        cp c
        jr z, .checkForCollisionXLeft
        ret

        .checkForCollisionXLeft:
        ld a, [PositionPlatformX]
        ld b, PLATFORM_COLLISION_OFFSET_X
        sub b
        ld c, a
        ld a, [PositionBallX]
        cp c
        jr nc, .checkForCollisionXRight
        ret

        .checkForCollisionXRight:
        ld a, SPRITE_WIDTH
        ld b, PLATFORM_COLLISION_OFFSET_X
        add b
        ld b, a
        ld a, [PositionPlatformX]
        add b
        ld c, a
        ld a, [PositionBallX]
        cp c
        call c, ChangeBallDirectionToUp
        ret
        

BallCheckCeilingCollision:
        ld a, [PositionBallY]
        cp SCREEN_LIMIT_CEILING
        jr c, .changeDirectionDown
        ret

        .changeDirectionDown:
        ld a, 1
        ld [BallDirectionY], a
        ret


BallCheckWallCollision:
        ld a, [PositionBallX]
        cp SCREEN_LIMIT_LEFT
        jr c, .changeDirectionRight

        ld a, [PositionBallX]
        cp SCREEN_LIMIT_RIGHT
        jr nc, .changeDirectionLeft

        ret

        .changeDirectionRight:
        ld a, 1
        ld [BallDirectionX], a
        ret

        .changeDirectionLeft:
        ld a, $FF
        ld [BallDirectionX], a
        ret
       

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
        ld a, [GameState]
        or a
        ret nz

        ld a, 1
        ld [GameState], a
        call GetRandomNumber
        ret

GetRandomNumber:
        ld a, [rDIV]
        and %00000011

        cp %11
        jr z, .one
        cp %01
        jr z, .minusone
        cp %00
        jr z, .zero

        .one:
        ld a, 1
        ld [Randi], a
        call SetRandomBallDirection
        ret

        .minusone:
        ld a, $FF
        ld [Randi], a
        call SetRandomBallDirection
        ret

        .zero:
        ld a, 0
        ld [Randi], a
        call SetRandomBallDirection
        ret

SetRandomBallDirection:
        ld a, [Randi]
        ld [BallDirectionX], a
        ld a, $FF
        ld [BallDirectionY], a
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

MoveBall:
        ld a, [PositionBallX]
        ld b, a
        ld a, [BallDirectionX]
        add b
        ld [PositionBallX], a

        ld a, [PositionBallY]
        ld b, a
        ld a, [BallDirectionY]
        add b
        ld [PositionBallY], a

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
        db 0, 4, 0, 20, 0, 36, 0, 52, 0, 68, 0, 84, 0, 100, 0, 116, 0, 132, 0, 148
        db 16, 4, 16, 20, 16, 36, 16, 52, 16, 68, 16, 84, 16, 100, 16, 116, 16, 132, 16, 148
