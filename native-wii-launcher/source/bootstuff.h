#ifndef ARKAIOS_BOOTSTUFF_H
#define ARKAIOS_BOOTSTUFF_H

#include <gccore.h>

#define MAX_TEXT_SECTIONS 7
#define MAX_DATA_SECTIONS 11

typedef struct {
    u32 textoff[MAX_TEXT_SECTIONS];
    u32 dataoff[MAX_DATA_SECTIONS];
    u32 textmem[MAX_TEXT_SECTIONS];
    u32 datamem[MAX_DATA_SECTIONS];
    u32 textsize[MAX_TEXT_SECTIONS];
    u32 datasize[MAX_DATA_SECTIONS];
    u32 bssmem;
    u32 bsssize;
    u32 entry;
} DolHeader;

int validate_dol(const u8 *buffer);
u32 relocate_dol(u8 *buffer, struct __argv *argv);

#endif
