# Security Policy

## Scope

This project prepares and launches Wii homebrew applications from SD/USB storage.

It intentionally does not:

- automate console exploits,
- install cIOS or modify NAND,
- download commercial ROMs,
- bypass ownership, DRM, or platform protections.

## Secrets

Do not commit API keys, GitHub tokens, passwords, NAND keys, private certificates, or account credentials.

If a credential is exposed, revoke or rotate it immediately.

## Supported Sources

Automated downloads are limited to homebrew/emulator packages and metadata from public homebrew repositories, plus Libretro thumbnail assets.

Users are responsible for providing their own legally obtained game backups.
