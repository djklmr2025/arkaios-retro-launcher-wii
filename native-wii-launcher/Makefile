ifeq ($(strip $(DEVKITPPC)),)
$(error "DEVKITPPC no esta definido. Instala devkitPro/wii-dev primero.")
endif

include $(DEVKITPPC)/wii_rules

TARGET := arkaios-wii-launcher
BUILD := build
SOURCES := source
DATA := data
INCLUDES :=

LIBS := -lwiiuse -lbte -logc -lm
LIBDIRS :=

CFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
OFILES := $(CFILES:.c=.o)

export OUTPUT := $(CURDIR)/$(TARGET)
export VPATH := $(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) $(foreach dir,$(DATA),$(CURDIR)/$(dir))
export DEPSDIR := $(CURDIR)/$(BUILD)

export INCLUDE := $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
	$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
	-I$(CURDIR)/$(BUILD)

export LIBPATHS := $(foreach dir,$(LIBDIRS),-L$(dir)/lib)

export CFLAGS := -g -O2 -Wall $(MACHDEP) $(INCLUDE)
export LDFLAGS := -g $(MACHDEP) -Wl,-Map,$(notdir $@).map

.PHONY: all clean

all: $(BUILD) $(OUTPUT).dol

$(BUILD):
	@[ -d $@ ] || mkdir -p $@

$(OUTPUT).dol: $(OUTPUT).elf
	$(OBJCOPY) -O binary $< $@

$(OUTPUT).elf: $(OFILES)

clean:
	@rm -rf $(BUILD) $(OUTPUT).elf $(OUTPUT).dol $(OUTPUT).elf.map

-include $(DEPSDIR)/*.d

