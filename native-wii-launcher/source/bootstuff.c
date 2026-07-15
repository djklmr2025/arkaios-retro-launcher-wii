#include <gccore.h>
#include <string.h>

#include "bootstuff.h"

int validate_dol(const u8 *buffer) {
    return buffer[0] == 0x00 && buffer[1] == 0x00 && buffer[2] == 0x01;
}

u32 relocate_dol(u8 *buffer, struct __argv *argv) {
    DolHeader *hdr = (DolHeader *)buffer;

    memset((void *)hdr->bssmem, 0, hdr->bsssize);

    for (int i = 0; i < MAX_TEXT_SECTIONS; i++) {
        if (!hdr->textsize[i]) {
            continue;
        }
        memcpy((void *)hdr->textmem[i], buffer + hdr->textoff[i], hdr->textsize[i]);
        DCFlushRange((void *)hdr->textmem[i], hdr->textsize[i]);
        ICInvalidateRange((void *)hdr->textmem[i], hdr->textsize[i]);
    }

    for (int i = 0; i < MAX_DATA_SECTIONS; i++) {
        if (!hdr->datasize[i]) {
            continue;
        }
        memcpy((void *)hdr->datamem[i], buffer + hdr->dataoff[i], hdr->datasize[i]);
        DCFlushRange((void *)hdr->datamem[i], hdr->datasize[i]);
    }

    if (argv && argv->argvMagic == ARGV_MAGIC) {
        memmove((void *)(hdr->entry + 8), argv, sizeof(*argv));
        DCFlushRange((void *)(hdr->entry + 8), sizeof(*argv));
    }

    return hdr->entry;
}
