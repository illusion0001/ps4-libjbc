#---------------------------------------------------------------------------------
# Clear the implicit built in rules
#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(OO_PS4_TOOLCHAIN)),)
$(error "Please set OO_PS4_TOOLCHAIN in your environment. export OO_PS4_TOOLCHAIN=<path>")
endif

# Check for linux vs macOS and account for clang/ld path
UNAME_S     := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
		CC      := clang
		CCX     := clang++
		LD      := ld.lld
		AR      := llvm-ar
		CDIR    := linux
endif
ifeq ($(UNAME_S),Darwin)
		CC      := /usr/local/opt/llvm/bin/clang
		CCX     := /usr/local/opt/llvm/bin/clang++
		LD      := /usr/local/opt/llvm/bin/ld.lld
		AR      := /usr/local/opt/llvm/bin/llvm-ar
		CDIR    := macos
endif

# Allow for 'make VERBOSE=1' to see the recepie executions
ifndef VERBOSE
  VERB := @
endif

#---------------------------------------------------------------------------------
%.a:
#---------------------------------------------------------------------------------
	$(VERB) echo $(notdir $@)
	$(VERB) rm -f $@
	$(VERB) $(AR) -rc $@ $^

#---------------------------------------------------------------------------------
%.elf: $(OFILES)
	$(VERB) echo linking ... $(notdir $@)
	$(VERB) $(LD)  $^ $(LDFLAGS) $(LIBPATHS) $(LIBS) -o $@

#---------------------------------------------------------------------------------
%.o: %.cpp
	$(VERB) echo $(notdir $<)
	$(VERB) $(CXX) $(DEPSOPT) $(CXXFLAGS) -o $@ $< $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.o: %.c
	$(VERB) echo $(notdir $<)
	$(VERB) $(CC) $(DEPSOPT) $(CFLAGS) -o $@ $< $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.o: %.m
	$(VERB) echo $(notdir $<)
	$(VERB) $(CC) $(DEPSOPT) $(OBJCFLAGS) -o $@ $< $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.o: %.s
	$(VERB) echo $(notdir $<)
	$(VERB) $(CC) $(DEPSOPT) -x assembler-with-cpp $(ASFLAGS) -o $@ $< $(ERROR_FILTER)

#---------------------------------------------------------------------------------
%.o: %.S
	$(VERB) echo $(notdir $<)
	$(VERB) $(CC) $(DEPSOPT) -x assembler-with-cpp $(ASFLAGS) -o $@ $< $(ERROR_FILTER)

#---------------------------------------------------------------------------------
# canned command sequence for binary data
#---------------------------------------------------------------------------------
define bin2o
	$(VERB) bin2s -a 64 $< | $(AS) -o $(@)
	$(VERB) echo "extern const u8" `(echo $(<F) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"_end[];" > `(echo $(<F) | tr . _)`.h
	$(VERB) echo "extern const u8" `(echo $(<F) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"[];" >> `(echo $(<F) | tr . _)`.h
	$(VERB) echo "extern const u32" `(echo $(<F) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`_size";" >> `(echo $(<F) | tr . _)`.h
endef

#---------------------------------------------------------------------------------
ifeq ($(strip $(PLATFORM)),)
#---------------------------------------------------------------------------------
export BASEDIR		:= $(CURDIR)
export DEPS			:= $(BASEDIR)/deps
export LIBS			:=	$(BASEDIR)/lib

#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------

export LIBDIR		:= $(LIBS)/$(PLATFORM)
export DEPSDIR		:=	$(DEPS)/$(PLATFORM)

#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

TARGET		:=	libjbc
BUILD		:=	build
SOURCE		:=	./
INCLUDE		:=	./
DATA		:=	data
LIBS		:=	
EXTRAFLAGS	:=	-nostdlib -ffreestanding -mno-red-zone

CFLAGS      += --target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -c $(EXTRAFLAGS) -isysroot $(OO_PS4_TOOLCHAIN) -isystem $(OO_PS4_TOOLCHAIN)/include $(INCLUDES)
CXXFLAGS    += $(CFLAGS) -isystem $(OO_PS4_TOOLCHAIN)/include/c++/v1

ifneq ($(BUILD),$(notdir $(CURDIR)))

export OUTPUT	:=	$(CURDIR)/$(TARGET)
export VPATH	:=	$(foreach dir,$(SOURCE),$(CURDIR)/$(dir)) \
					$(foreach dir,$(DATA),$(CURDIR)/$(dir))
export BUILDDIR	:=	$(CURDIR)/$(BUILD)
export DEPSDIR	:=	$(BUILDDIR)

CFILES		:= $(foreach dir,$(SOURCE),$(notdir $(wildcard $(dir)/*.c)))
CXXFILES	:= $(foreach dir,$(SOURCE),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES		:= $(foreach dir,$(SOURCE),$(notdir $(wildcard $(dir)/*.S)))
BINFILES	:= $(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.bin)))

export OFILES	:=	$(CFILES:.c=.o) \
					$(CXXFILES:.cpp=.o) \
					$(SFILES:.S=.o) \
					$(BINFILES:.bin=.bin.o)

export BINFILES	:=	$(BINFILES:.bin=.bin.h)

export INCLUDES	=	$(foreach dir,$(INCLUDE),-I$(CURDIR)/$(dir)) \
					-I$(CURDIR)/$(BUILD) -I$(OO_PS4_TOOLCHAIN)/include

.PHONY: $(BUILD) install clean

$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@make --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

install: $(BUILD)
	@echo Copying...
	@cp -frv libjbc.h $(OO_PS4_TOOLCHAIN)/include
	@cp -frv $(TARGET).a $(OO_PS4_TOOLCHAIN)/lib
	@echo lib installed!
clean:
	@echo Clean...
	@rm -rf $(BUILD) $(OUTPUT).elf $(OUTPUT).self $(OUTPUT).a

else

DEPENDS	:= $(OFILES:.o=.d)

$(OUTPUT).a: $(OFILES)
$(OFILES): $(BINFILES)

-include $(DEPENDS)

endif
