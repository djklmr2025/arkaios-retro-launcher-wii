# WAD VC Injection Review

Reviewed local file:

`D:\WAD\Super Mario Bros. 3 [Español] [NES] [NTSC(U)] by Aldo.wad`

This document records structural findings only. It does not extract or reuse the embedded game content.

## Summary

The WAD is not a normal SD/USB forwarder and it is not using `apps/snes9xgx/boot.dol`.

It is a modified Wii channel/Virtual Console style WAD:

- Channel name: `Super Mario Bros. 3`
- WAD type: standard installable
- Title ID: `0001000146435745`
- ASCII title code: `FCWE`
- Required IOS: `IOS21`
- Region: none
- AHB access: false
- Signing status: modified ticket/TMD
- Contents: 7
- Boot content index: `6`

## Content Layout

TMD content records:

| Index | Content ID | Type | Size | Notes |
| --- | --- | --- | ---: | --- |
| 0 | `00000000` | Normal | 1,084,048 | U8 archive, likely banner/icon/channel metadata |
| 1 | `00000001` | Normal | 2,148,544 | DOL-like binary, likely VC emulator/application |
| 2 | `00000002` | Shared | 4,559,887 | U8/resource/content archive |
| 3 | `00000003` | Shared | 2,669,044 | U8/resource/content archive |
| 4 | `00000004` | Shared | 2,156,800 | U8/resource/content archive |
| 5 | `00000005` | Normal | 773,612 | U8/resource/content archive |
| 6 | `00000006` | Normal | 271,616 | Boot content; NAND boot program |

## Boot Logic

The actual boot index is `6`. Strings inside `00000006.app` identify it as:

`NAND BOOT PROGRAM v1.1`

It references Wii ES/content APIs such as:

- `ES_InitLib`
- `ES_OpenContentFile`
- `ES_ReadContentFile`
- `ES_CloseContentFile`
- `ES_CloseLib`

This means the channel is launched as an installed NAND title. The boot content then reads title contents through IOS/ES, not through a regular SD/USB filesystem path.

## Emulator Logic

Strings in `00000001.app` include Virtual Console/NES-like runtime terms such as:

- `PPU`
- `ROM`
- `VC`
- `Classic Controller`
- Wii Menu/system-memory messages

This suggests the WAD carries a VC-style emulator/application internally. The game data is embedded as title content, not loaded as a standalone `.nes` file from `/Roms`.

## Impact For ARKAIOS

This WAD does not solve direct launching of loose SNES `.sfc` files through Snes9x GX.

It does give ARKAIOS a separate viable path:

1. Catalog WAD/VC/WiiWare titles by Title ID.
2. Install user-owned/homebrew WAD titles into EmuNAND, not real NAND.
3. Launch those titles through a loader that supports EmuNAND/neek2o, such as USB Loader GX or WiiFlow.
4. Treat these as a separate platform family in ARKAIOS: `Wii Channel / EmuNAND`, not `SNES ROM`.

Recommended ARKAIOS categories:

- `Wii/WBFS`: launch through CFG/USB Loader flow, already working.
- `Homebrew ROM`: open native homebrew emulators manually or through safe app-specific flows.
- `EmuNAND Channel`: detect `title/00010001/<titleid>` and launch via loader/neek2o.

## Channel/Forwarder Direction

For an official ARKAIOS channel, do not use this WAD as a base. It contains game-specific Virtual Console content.

Use a clean homebrew forwarder base instead:

- Title ID suggestion: `AKOS`
- Display name: `ARKAIOS Retro Launcher`
- Target path: `sd:/apps/arkaios-wii-launcher/boot.dol`
- Fallback path: `usb:/apps/arkaios-wii-launcher/boot.dol`

The forwarder channel should only start the ARKAIOS homebrew app. It should not embed commercial game content.
