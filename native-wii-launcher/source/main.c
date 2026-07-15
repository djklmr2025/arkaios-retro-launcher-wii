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
#define MAX_METADATA 768
#define MAX_PATH_LEN 512

typedef struct {
    char path[MAX_PATH_LEN];
    char name[96];
    char title[128];
    char system[64];
    char launcher[96];
    char app[96];
    char cover[MAX_PATH_LEN];
} RomEntry;

typedef struct {
    char key[96];
    char title[128];
    char system[64];
    char launcher[96];
    char cover[MAX_PATH_LEN];
} MetadataEntry;

static void *xfb = NULL;
static GXRModeObj *rmode = NULL;
static RomEntry roms[MAX_ROMS];
static MetadataEntry metadata[MAX_METADATA];
static int rom_count = 0;
static int metadata_count = 0;
static int selected = 0;
static int top = 0;
static int sd_mounted = 0;
static int usb_mounted = 0;
static char sd_debug[256] = "";
static char last_app_path[MAX_PATH_LEN] = "";

static const char *base_name(const char *path);

static int file_exists(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        return 0;
    }
    fclose(file);
    return 1;
}

static int extract_wii_game_id(const RomEntry *rom, char *game_id, size_t game_id_size) {
    const char *sources[] = { rom->name, base_name(rom->path), rom->path };
    for (int s = 0; s < 3; s++) {
        const char *value = sources[s];
        size_t len = strlen(value);
        for (size_t i = 0; i + 6 <= len; i++) {
            int ok = 1;
            for (int j = 0; j < 6; j++) {
                char c = value[i + j];
                if (!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))) {
                    ok = 0;
                    break;
                }
            }
            if (ok) {
                snprintf(game_id, game_id_size, "%.6s", value + i);
                return 1;
            }
        }
    }
    return 0;
}

static void build_launch_args(const char *dol_path, const char *launch_arg, struct __argv *args) {
    memset(args, 0, sizeof(*args));
    args->argvMagic = ARGV_MAGIC;
    args->argc = launch_arg && launch_arg[0] ? 2 : 1;
    args->length = strlen(dol_path) + 1 + (args->argc == 2 ? strlen(launch_arg) + 1 : 0);
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
        strcpy(cursor, launch_arg);
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

static void prepare_for_chainload(void) {
    fatUnmount("sd");
    fatUnmount("usb");
    WPAD_Shutdown();
    VIDEO_Flush();
    VIDEO_WaitVSync();
}

static int try_app_path(const char *relative, char *path, size_t path_size) {
    const char *prefixes[] = { "sd:/", "usb:/" };
    for (int i = 0; i < 2; i++) {
        snprintf(path, path_size, "%s%s", prefixes[i], relative);
        if (file_exists(path)) {
            return 1;
        }
    }
    snprintf(path, path_size, "sd:/%s", relative);
    return 0;
}

static int app_boot_path(const RomEntry *rom, char *path, size_t path_size) {
    if (!strcmp(rom->app, "snes9xgx")) {
        return try_app_path("apps/snes9xgx/boot.dol", path, path_size);
    }
    if (!strcmp(rom->app, "usbloader_gx")) {
        return try_app_path("apps/usbloader_gx/boot.dol", path, path_size);
    }
    if (!strcmp(rom->app, "USBLoader")) {
        return try_app_path("apps/USBLoader/boot.dol", path, path_size);
    }
    if (!strcmp(rom->app, "Nintendont")) {
        return try_app_path("apps/nintendont/boot.dol", path, path_size);
    }
    if (!strcmp(rom->app, "not64")) {
        return try_app_path("apps/not64/boot.dol", path, path_size);
    }
    if (!strcmp(rom->app, "DeSmuMEWii")) {
        return try_app_path("apps/DeSmuMEWii/boot.dol", path, path_size);
    }
    return 0;
}

static int launch_app_for_rom(const RomEntry *rom, char *error, size_t error_size) {
    char dol_path[MAX_PATH_LEN];
    if (!app_boot_path(rom, dol_path, sizeof(dol_path))) {
        snprintf(error, error_size, "No encontre app para %s en sd:/apps ni usb:/apps", rom->app);
        return 0;
    }
    snprintf(last_app_path, sizeof(last_app_path), "%s", dol_path);

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

    char launch_arg[MAX_PATH_LEN];
    snprintf(launch_arg, sizeof(launch_arg), "%s", rom->path);
    if (!strcmp(rom->app, "USBLoader")) {
        char game_id[8];
        if (!extract_wii_game_id(rom, game_id, sizeof(game_id))) {
            free(dol);
            snprintf(error, error_size, "No pude extraer GAMEID para Configurable USB Loader");
            return 0;
        }
        snprintf(launch_arg, sizeof(launch_arg), "#%s", game_id);
    }

    struct __argv args;
    build_launch_args(dol_path, launch_arg, &args);
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
    prepare_for_chainload();
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

static const char *base_name(const char *path) {
    const char *slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

static void strip_extension(char *value) {
    char *dot = strrchr(value, '.');
    if (dot) {
        *dot = '\0';
    }
}

static const char *short_system(const char *system) {
    if (strstr(system, "Super Nintendo") || !strcasecmp(system, "SNES")) {
        return "SNES";
    }
    if (strstr(system, "Nintendo - Wii") || !strcasecmp(system, "Wii")) {
        return "Wii";
    }
    if (strstr(system, "GameCube")) {
        return "GC";
    }
    if (strstr(system, "Nintendo 64")) {
        return "N64";
    }
    if (strstr(system, "Nintendo DS")) {
        return "NDS";
    }
    if (strstr(system, "Game Boy Advance") || !strcasecmp(system, "GBA")) {
        return "GBA";
    }
    return system;
}

static void trim_newline(char *value) {
    size_t len = strlen(value);
    while (len > 0 && (value[len - 1] == '\n' || value[len - 1] == '\r')) {
        value[len - 1] = '\0';
        len--;
    }
}

static void load_metadata_file(const char *path) {
    FILE *file = fopen(path, "r");
    if (!file) {
        return;
    }

    char line[1024];
    while (metadata_count < MAX_METADATA && fgets(line, sizeof(line), file)) {
        trim_newline(line);
        if (line[0] == '\0' || line[0] == '#') {
            continue;
        }

        char *key = strtok(line, "|");
        char *title = strtok(NULL, "|");
        char *system = strtok(NULL, "|");
        char *launcher = strtok(NULL, "|");
        char *cover = strtok(NULL, "|");
        if (!key || !title) {
            continue;
        }

        snprintf(metadata[metadata_count].key, sizeof(metadata[metadata_count].key), "%s", key);
        snprintf(metadata[metadata_count].title, sizeof(metadata[metadata_count].title), "%s", title);
        snprintf(metadata[metadata_count].system, sizeof(metadata[metadata_count].system), "%s", system ? system : "");
        snprintf(metadata[metadata_count].launcher, sizeof(metadata[metadata_count].launcher), "%s", launcher ? launcher : "");
        snprintf(metadata[metadata_count].cover, sizeof(metadata[metadata_count].cover), "%s", cover ? cover : "");
        metadata_count++;
    }

    fclose(file);
}

static void load_metadata(void) {
    load_metadata_file("sd:/retroarch/arkaios/metadata.txt");
    load_metadata_file("usb:/retroarch/arkaios/metadata.txt");
}

static const MetadataEntry *find_metadata(const char *full_path, const char *file_name) {
    char stem[256];
    snprintf(stem, sizeof(stem), "%s", file_name);
    strip_extension(stem);

    for (int i = 0; i < metadata_count; i++) {
        if (!strcasecmp(metadata[i].key, file_name) || !strcasecmp(metadata[i].key, stem)) {
            return &metadata[i];
        }
        if (strstr(full_path, metadata[i].key)) {
            return &metadata[i];
        }
    }
    return NULL;
}

static int detect_rom(const char *file, char *system, size_t system_size, char *launcher, size_t launcher_size, char *app, size_t app_size) {
    if (ends_with_ci(file, ".wbfs")) {
        snprintf(system, system_size, "Wii");
        snprintf(launcher, launcher_size, "Configurable USB Loader");
        snprintf(app, app_size, "USBLoader");
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
    const MetadataEntry *meta = find_metadata(path, name);

    snprintf(roms[rom_count].path, sizeof(roms[rom_count].path), "%s", path);
    snprintf(roms[rom_count].name, sizeof(roms[rom_count].name), "%s", name);
    snprintf(roms[rom_count].title, sizeof(roms[rom_count].title), "%s", meta ? meta->title : name);
    snprintf(roms[rom_count].system, sizeof(roms[rom_count].system), "%s", meta && meta->system[0] ? meta->system : system);
    snprintf(roms[rom_count].launcher, sizeof(roms[rom_count].launcher), "%s", meta && meta->launcher[0] ? meta->launcher : launcher);
    snprintf(roms[rom_count].app, sizeof(roms[rom_count].app), "%s", app);
    snprintf(roms[rom_count].cover, sizeof(roms[rom_count].cover), "%s", meta ? meta->cover : "");
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

    for (int i = 0; i < 15 && (top + i) < rom_count; i++) {
        int idx = top + i;
        printf("%c %-5s %.36s\n", idx == selected ? '>' : ' ', short_system(roms[idx].system), roms[idx].title);
    }

    printf("\x1b[4;48HSeleccionado");
    printf("\x1b[6;48H%.30s", roms[selected].title);
    printf("\x1b[8;48HSistema:");
    printf("\x1b[9;48H%.30s", roms[selected].system);
    printf("\x1b[11;48HLauncher:");
    printf("\x1b[12;48H%.30s", roms[selected].launcher);
    printf("\x1b[14;48HArchivo:");
    printf("\x1b[15;48H%.30s", base_name(roms[selected].path));
    printf("\x1b[17;48HCover:");
    printf("\x1b[18;48H%.30s", roms[selected].cover[0] ? base_name(roms[selected].cover) : "pendiente");
    printf("\x1b[20;48HApp:");
    printf("\x1b[21;48H%.30s", roms[selected].app);
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

    printf("\x1b[22;1HHandoff creado:\n");
    printf("%.72s\n", rom->name);

    char error[160];
    printf("\nLanzando %s...\n", rom->launcher);
    VIDEO_WaitVSync();
    if (!launch_app_for_rom(rom, error, sizeof(error))) {
        printf("\nNo se pudo lanzar directo:\n%s\n", error);
    } else {
        printf("\nApp usada: %.70s\n", last_app_path);
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
    load_metadata();

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
            if (selected >= top + 15) {
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
