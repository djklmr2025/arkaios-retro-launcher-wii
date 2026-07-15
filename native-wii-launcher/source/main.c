#include <gccore.h>
#include <wiiuse/wpad.h>
#include <fat.h>
#include <ogc/usbstorage.h>
#include <sdcard/wiisd_io.h>
#include <dirent.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bootstuff.h"

#define MAX_ROMS 512
#define MAX_PATH_LEN 512

typedef struct {
    char path[MAX_PATH_LEN];
    char name[96];
    char system[64];
    char launcher[96];
    char app[96];
} RomEntry;

static void *xfb = NULL;
static GXRModeObj *rmode = NULL;
static RomEntry roms[MAX_ROMS];
static int rom_count = 0;
static int selected = 0;
static int top = 0;
static int sd_mounted = 0;
static int usb_mounted = 0;
static char sd_debug[256] = "";

static void build_launch_args(const char *dol_path, const char *rom_path, struct __argv *args) {
    memset(args, 0, sizeof(*args));
    args->argvMagic = ARGV_MAGIC;
    args->argc = rom_path && rom_path[0] ? 2 : 1;
    args->length = strlen(dol_path) + 1 + (args->argc == 2 ? strlen(rom_path) + 1 : 0);
    args->commandLine = (char *)malloc(args->length);
    args->argv = (char **)malloc(sizeof(char *) * args->argc);

    if (!args->commandLine || !args->argv) {
        args->argvMagic = 0;
        return;
    }

    char *cursor = args->commandLine;
    strcpy(cursor, dol_path);
    args->argv[0] = cursor;
    cursor += strlen(cursor) + 1;

    if (args->argc == 2) {
        strcpy(cursor, rom_path);
        args->argv[1] = cursor;
    }

    args->endARGV = args->argv + args->argc;
}

static int read_file_to_memory(const char *path, u8 **buffer, size_t *size) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        return 0;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (file_size <= 0) {
        fclose(file);
        return 0;
    }

    u8 *data = (u8 *)memalign(32, (size_t)file_size);
    if (!data) {
        fclose(file);
        return 0;
    }

    size_t read = fread(data, 1, (size_t)file_size, file);
    fclose(file);

    if (read != (size_t)file_size) {
        free(data);
        return 0;
    }

    DCFlushRange(data, (size_t)file_size);
    *buffer = data;
    *size = (size_t)file_size;
    return 1;
}

static void shutdown_for_chainload(void) {
    fatUnmount("sd");
    fatUnmount("usb");
    WPAD_Shutdown();
    VIDEO_SetBlack(TRUE);
    VIDEO_Flush();
    VIDEO_WaitVSync();
    SYS_ResetSystem(SYS_SHUTDOWN, 0, 0);
}

static int app_boot_path(const RomEntry *rom, char *path, size_t path_size) {
    if (!strcmp(rom->app, "snes9xgx")) {
        snprintf(path, path_size, "%s", sd_mounted ? "sd:/apps/snes9xgx/boot.dol" : "usb:/apps/snes9xgx/boot.dol");
        return 1;
    }
    if (!strcmp(rom->app, "usbloader_gx")) {
        snprintf(path, path_size, "%s", sd_mounted ? "sd:/apps/usbloader_gx/boot.dol" : "usb:/apps/usbloader_gx/boot.dol");
        return 1;
    }
    if (!strcmp(rom->app, "Nintendont")) {
        snprintf(path, path_size, "%s", sd_mounted ? "sd:/apps/nintendont/boot.dol" : "usb:/apps/nintendont/boot.dol");
        return 1;
    }
    if (!strcmp(rom->app, "not64")) {
        snprintf(path, path_size, "%s", sd_mounted ? "sd:/apps/not64/boot.dol" : "usb:/apps/not64/boot.dol");
        return 1;
    }
    if (!strcmp(rom->app, "DeSmuMEWii")) {
        snprintf(path, path_size, "%s", sd_mounted ? "sd:/apps/DeSmuMEWii/boot.dol" : "usb:/apps/DeSmuMEWii/boot.dol");
        return 1;
    }
    return 0;
}

static int launch_app_for_rom(const RomEntry *rom, char *error, size_t error_size) {
    char dol_path[MAX_PATH_LEN];
    if (!app_boot_path(rom, dol_path, sizeof(dol_path))) {
        snprintf(error, error_size, "Sin launcher directo para %s", rom->app);
        return 0;
    }

    u8 *dol = NULL;
    size_t dol_size = 0;
    if (!read_file_to_memory(dol_path, &dol, &dol_size)) {
        snprintf(error, error_size, "No pude leer %s", dol_path);
        return 0;
    }

    if (!validate_dol(dol)) {
        free(dol);
        snprintf(error, error_size, "El launcher no parece DOL valido");
        return 0;
    }

    struct __argv args;
    build_launch_args(dol_path, rom->path, &args);
    if (args.argvMagic != ARGV_MAGIC) {
        free(dol);
        snprintf(error, error_size, "No pude crear argumentos");
        return 0;
    }

    void (*entry)(void) = (void (*)(void))relocate_dol(dol, &args);
    free(dol);

    if (!entry) {
        snprintf(error, error_size, "No pude reubicar el DOL");
        return 0;
    }

    *(vu32 *)0x800000F8 = 0x0E7BE2C0;
    *(vu32 *)0x800000FC = 0x2B73A840;
    shutdown_for_chainload();
    entry();
    return 1;
}

static void init_video(void) {
    VIDEO_Init();
    WPAD_Init();
    rmode = VIDEO_GetPreferredMode(NULL);
    xfb = MEM_K0_TO_K1(SYS_AllocateFramebuffer(rmode));
    console_init(xfb, 20, 20, rmode->fbWidth, rmode->xfbHeight, rmode->fbWidth * VI_DISPLAY_PIX_SZ);
    VIDEO_Configure(rmode);
    VIDEO_SetNextFramebuffer(xfb);
    VIDEO_SetBlack(FALSE);
    VIDEO_Flush();
    VIDEO_WaitVSync();
    if (rmode->viTVMode & VI_NON_INTERLACE) {
        VIDEO_WaitVSync();
    }
}

static int ends_with_ci(const char *value, const char *suffix) {
    size_t value_len = strlen(value);
    size_t suffix_len = strlen(suffix);
    if (suffix_len > value_len) {
        return 0;
    }
    return strcasecmp(value + value_len - suffix_len, suffix) == 0;
}

static int detect_rom(const char *file, char *system, size_t system_size, char *launcher, size_t launcher_size, char *app, size_t app_size) {
    if (ends_with_ci(file, ".wbfs")) {
        snprintf(system, system_size, "Wii");
        snprintf(launcher, launcher_size, "USB Loader GX");
        snprintf(app, app_size, "usbloader_gx");
        return 1;
    }
    if (ends_with_ci(file, ".iso") || ends_with_ci(file, ".gcm") || ends_with_ci(file, ".ciso")) {
        snprintf(system, system_size, "GameCube");
        snprintf(launcher, launcher_size, "Nintendont");
        snprintf(app, app_size, "Nintendont");
        return 1;
    }
    if (ends_with_ci(file, ".n64") || ends_with_ci(file, ".z64") || ends_with_ci(file, ".v64")) {
        snprintf(system, system_size, "Nintendo 64");
        snprintf(launcher, launcher_size, "Not64");
        snprintf(app, app_size, "not64");
        return 1;
    }
    if (ends_with_ci(file, ".nds")) {
        snprintf(system, system_size, "Nintendo DS");
        snprintf(launcher, launcher_size, "DeSmuME Wii");
        snprintf(app, app_size, "DeSmuMEWii");
        return 1;
    }
    if (ends_with_ci(file, ".sfc") || ends_with_ci(file, ".smc")) {
        snprintf(system, system_size, "SNES");
        snprintf(launcher, launcher_size, "Snes9x GX");
        snprintf(app, app_size, "snes9xgx");
        return 1;
    }
    if (ends_with_ci(file, ".nes")) {
        snprintf(system, system_size, "NES");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "fceumm_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".gba")) {
        snprintf(system, system_size, "GBA");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "mgba_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".gbc")) {
        snprintf(system, system_size, "GBC");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "gambatte_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".gb")) {
        snprintf(system, system_size, "GB");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "gambatte_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".md") || ends_with_ci(file, ".gen") || ends_with_ci(file, ".smd")) {
        snprintf(system, system_size, "Genesis");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "genesis_plus_gx_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".sms")) {
        snprintf(system, system_size, "Master System");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "genesis_plus_gx_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".gg")) {
        snprintf(system, system_size, "Game Gear");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "genesis_plus_gx_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".a26")) {
        snprintf(system, system_size, "Atari 2600");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "stella2014_libretro_wii.dol");
        return 1;
    }
    if (ends_with_ci(file, ".pce")) {
        snprintf(system, system_size, "PC Engine");
        snprintf(launcher, launcher_size, "RetroArch Wii");
        snprintf(app, app_size, "mednafen_pce_fast_libretro_wii.dol");
        return 1;
    }
    return 0;
}

static void add_rom(const char *path, const char *name, const char *system, const char *launcher, const char *app) {
    if (rom_count >= MAX_ROMS) {
        return;
    }
    snprintf(roms[rom_count].path, sizeof(roms[rom_count].path), "%s", path);
    snprintf(roms[rom_count].name, sizeof(roms[rom_count].name), "%s", name);
    snprintf(roms[rom_count].system, sizeof(roms[rom_count].system), "%s", system);
    snprintf(roms[rom_count].launcher, sizeof(roms[rom_count].launcher), "%s", launcher);
    snprintf(roms[rom_count].app, sizeof(roms[rom_count].app), "%s", app);
    rom_count++;
}

static void scan_dir(const char *base) {
    DIR *dir = opendir(base);
    if (!dir) {
        return;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) {
            continue;
        }

        char full[MAX_PATH_LEN];
        snprintf(full, sizeof(full), "%s/%s", base, entry->d_name);

        if (entry->d_type == DT_DIR) {
            scan_dir(full);
            continue;
        }

        char system[64];
        char launcher[96];
        char app[96];
        if (detect_rom(entry->d_name, system, sizeof(system), launcher, sizeof(launcher), app, sizeof(app))) {
            add_rom(full, entry->d_name, system, launcher, app);
        }
    }

    closedir(dir);
}

static void collect_sd_debug(void) {
    DIR *dir = opendir("sd:/");
    if (!dir) {
        snprintf(sd_debug, sizeof(sd_debug), "sd:/ no abre");
        return;
    }

    snprintf(sd_debug, sizeof(sd_debug), "sd:/");
    struct dirent *entry;
    int count = 0;
    while ((entry = readdir(dir)) != NULL && count < 4) {
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) {
            continue;
        }
        strncat(sd_debug, " ", sizeof(sd_debug) - strlen(sd_debug) - 1);
        strncat(sd_debug, entry->d_name, sizeof(sd_debug) - strlen(sd_debug) - 1);
        count++;
    }
    if (count == 0) {
        strncat(sd_debug, " vacio", sizeof(sd_debug) - strlen(sd_debug) - 1);
    }
    closedir(dir);
}

static void draw(void) {
    printf("\x1b[2J");
    printf("\x1b[1;1HARKAIOS Retro Launcher Wii\n");
    printf("A: preparar lanzamiento | HOME: salir | ROMs: %d\n\n", rom_count);

    if (rom_count == 0) {
        printf("SD: %s | USB: %s\n", sd_mounted ? "montada" : "no montada", usb_mounted ? "montada" : "no montada");
        printf("%s\n", sd_debug);
        printf("No se encontraron ROMs compatibles en sd:/Roms o usb:/Roms.\n");
        printf("Usa la herramienta de Windows para crear playlists y portadas.\n");
        return;
    }

    for (int i = 0; i < 18 && (top + i) < rom_count; i++) {
        int idx = top + i;
        printf("%c %-10s %s\n", idx == selected ? '>' : ' ', roms[idx].system, roms[idx].name);
    }

    printf("\nSeleccionado:\n");
    printf("Launcher: %s\n", roms[selected].launcher);
    printf("App/Core : %s\n", roms[selected].app);
    printf("ROM : %s\n", roms[selected].path);
}

static void prepare_launch(const RomEntry *rom) {
    FILE *handoff = fopen("sd:/retroarch/arkaios-launch.txt", "w");
    if (!handoff) {
        handoff = fopen("usb:/retroarch/arkaios-launch.txt", "w");
    }
    if (handoff) {
        fprintf(handoff, "launcher=%s\n", rom->launcher);
        fprintf(handoff, "app=%s\n", rom->app);
        fprintf(handoff, "rom=%s\n", rom->path);
        fclose(handoff);
    }

    printf("\nHandoff creado:\n");
    printf("%s\n", rom->name);

    char error[160];
    printf("\nLanzando %s...\n", rom->launcher);
    VIDEO_WaitVSync();
    if (!launch_app_for_rom(rom, error, sizeof(error))) {
        printf("\nNo se pudo lanzar directo:\n%s\n", error);
    }

    printf("Presiona B para volver.\n");
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    init_video();
    sd_mounted = fatMountSimple("sd", &__io_wiisd) ? 1 : 0;
    usb_mounted = fatMountSimple("usb", &__io_usbstorage) ? 1 : 0;
    collect_sd_debug();

    scan_dir("sd:/Roms");
    scan_dir("usb:/Roms");
    scan_dir("sd:/wbfs");
    scan_dir("usb:/wbfs");
    scan_dir("sd:/games");
    scan_dir("usb:/games");

    while (1) {
        draw();
        WPAD_ScanPads();
        u32 pressed = WPAD_ButtonsDown(0);

        if (pressed & WPAD_BUTTON_HOME) {
            break;
        }
        if ((pressed & WPAD_BUTTON_DOWN) && selected < rom_count - 1) {
            selected++;
            if (selected >= top + 18) {
                top++;
            }
        }
        if ((pressed & WPAD_BUTTON_UP) && selected > 0) {
            selected--;
            if (selected < top) {
                top--;
            }
        }
        if ((pressed & WPAD_BUTTON_A) && rom_count > 0) {
            prepare_launch(&roms[selected]);
            while (1) {
                WPAD_ScanPads();
                u32 p = WPAD_ButtonsDown(0);
                if (p & WPAD_BUTTON_B) {
                    break;
                }
                VIDEO_WaitVSync();
            }
        }

        VIDEO_WaitVSync();
    }

    return 0;
}
