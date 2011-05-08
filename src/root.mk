_push = $(eval _save1$1 := $(MAKEFILE_LIST))$(eval _save2$1 := $(_MODULE_NAME))\
    $(eval _save3$1 := $(_MODULE_PATH))$(eval _save4$1 := $(_MODULE))
_pop = $(eval MAKEFILE_LIST := $(_save1$1))$(eval _MODULE_NAME := $(_save2$1))\
    $(eval _MODULE_PATH := $(_save3$1))$(eval _MODULE := $(_save4$1))
_INCLUDE = $(call _push,$1)$(eval include $(_ROOT)/$1/Makefile)$(call _pop,$1)
DEPENDS_ON = $(call _INCLUDE,$1) 
DEPENDS_ON_NO_BUILD = $(eval _NO_RULES := T)$(call _INCLUDE,$1)$(eval _NO_RULES :=)

# To be overwritten by command line
ARCH = x86
CFLAGS = -g -O2 -Wall
ASFLAGS = -g -F dwarf
LDFLAGS =

AS = gcc
ASM = nasm
CC = gcc
CXX = g++
AR = ar
RM = rm -f
STAT = stat
OBJCOPY = objcopy
DD = dd

VERBOSE_AS =
VERBOSE_ASM =
VERBOSE_CC =
VERBOSE_CXX =
VERBOSE_AR =
VERBOSE_LINK =
VERBOSE_RM = 
VERBOSE_BIN =

QUIET_AS = @echo 'AS    '$(call local_src,$<) &&
QUIET_ASM = @echo 'ASM   '$(call local_src,$<) &&
QUIET_CC = @echo 'CC    '$(call local_src,$<) &&
QUIET_CXX = @echo 'CXX   '$(call local_src,$<) && 
QUIET_AR = @echo 'AR    '$$(call local_build,$$@) && 
QUIET_LINK = @echo 'LINK  '$$(call local_build,$$@) && 
QUIET_RM = @echo 'CLEAN ' $(patsubst clean-%,%,$@) &&
QUIET_BIN = @echo 'BIN   '$$(call local_build,$$@) &&

SILENT_AS = @
SILENT_ASM = @
SILENT_CC = @
SILENT_CXX = @
SILENT_AR = @
SILENT_LINK = @
SILENT_RM = @
SILENT_BIN = @

ifeq ("$(origin V)", "command line")
  VERBOSE = $(V)
endif
ifndef VERBOSE
  VERBOSE = 0
endif

ifeq ($(VERBOSE),0)
  MODE = QUIET_
  Q = @
else
  MODE = VERBOSE_
  Q = 
endif

ifneq ($(findstring s,$(MAKEFLAGS)),)
  MODE = SILENT_
endif

ALL_CFLAGS = $(CFLAGS)
ALL_ASFLAGS = -f elf $(ASFLAGS)
ALL_LDFLAGS = $(LDFLAGS)

ALL_CFLAGS += -fno-stack-protector

INCLUDE_DIRS_C := $(_ROOT)/include
INCLUDE_DIRS_ASM := $(_ROOT)/include/

#include $(_ROOT)/arch/$(ARCH)/config.mk

define _PREFIX_TPL
_TN := $(call local_target,$(1))
$$(_TN)_DISPLAYNAME := $(_MODULE)/$(1)
$$(_TN)_SRCS = $(addprefix $(_MODULE_PATH),$(2))
$$(_TN)_OBJS = $(addsuffix $(_OBJ_EXT),$(addprefix $($(_MODULE_NAME)_OUTPUT)/,$(basename $(2))))
.PHONY: $$(_TN)
endef

define LIBRARY_TPL
$$(info Registering library $$($$(_TN)_DISPLAYNAME)...)
$$(_TN)_PATH := $($(_MODULE_NAME)_OUTPUT)/$(1)$(_LIB_EXT)
$$(_TN) : $$($$(_TN)_PATH)
$$($$(_TN)_PATH) : $$($$(_TN)_OBJS) $$(call get_tpath,$$($$(_TN)_TDEPS))
	$($(MODE)LINK)$(LD) $$(ALL_LDFLAGS) -r -o $$@ $$(filter %.o,$$^)
endef

define EXECUTABLE_TPL
$$(info Registering executable $$($$(_TN)_DISPLAYNAME)...)
$$(_TN)_PATH := $($(_MODULE_NAME)_OUTPUT)/$(1)$(_EXE_EXT)
$$(_TN) : $$($$(_TN)_PATH)
$$(_TN)_OBJS += $$(call get_tpath,$$($$(_TN)_TDEPS))
$$($$(_TN)_PATH) : $$(call get_tpath,$$($$(_TN)_EXTRA_TDEPS)) $$($$(_TN)_LDSCRIPT) $$($$(_TN)_OBJS) 
	$($(MODE)LINK)$(LD) $$(addprefix -T ,$$(filter %.ld,$$^)) $$(filter %.o,$$^) $$(ALL_LDFLAGS) -o $$@
endef

define HOST_EXECUTABLE_TPL
$$(info Registering host executable $$($$(_TN)_DISPLAYNAME)...)
$$(_TN)_PATH := $($(_MODULE_NAME)_OUTPUT)/$(1)$(_EXE_EXT)
$$(_TN) : $$($$(_TN)_PATH)
$$(_TN)_OBJS += $$(call get_tpath,$$($$(_TN)_TDEPS))
$$($$(_TN)_PATH) : $$(call get_tpath,$$($$(_TN)_EXTRA_TDEPS)) $$($$(_TN)_LDSCRIPT) $$($$(_TN)_OBJS) 
	$($(MODE)LINK)$(CC) $$(filter %.o,$$^) $$(addprefix --Wl,$$(ALL_LDFLAGS)) -o $$@
endef

define BINARY_TPL
$$(info Registering binary $$($$(_TN)_DISPLAYNAME)...)
$$(_TN)_PATH := $($(_MODULE_NAME)_OUTPUT)/$(1)$(_BIN_EXT)
$$(_TN) : $$($$(_TN)_PATH)
$$($$(_TN)_PATH) : $$($$(_TN)_OBJS) $$(call get_tpath,$$($$(_TN)_TDEPS))
	$($(MODE)BIN)$(OBJCOPY) -O binary -S $$< $$@
endef

define CUSTOM_TPL
$$(info Registering custom target $$($$(_TN)_DISPLAYNAME)...)
$$(_TN)_PATH := $($(_MODULE_NAME)_OUTPUT)/$$($$(_TN)_OUTPUT)
$$(_TN) : $$($$(_TN)_PATH)
endef
