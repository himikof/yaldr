# Tools Makefile

# Magic header, do not touch
sp :=
sp +=
_walk = $(if $1,$(wildcard /$(subst $(sp),/,$1)/$2) $(call _walk,$(wordlist 2,$(words $1),x $1),$2))
_find = $(firstword $(call _walk,$(strip $(subst /, ,$1)),$2))
_ROOT ?= $(patsubst %/root.mk,%,$(call _find,$(CURDIR),root.mk))
include $(_ROOT)/root.mk
include $(_ROOT)/prefix.mk
# End of magic


$(call DEPENDS_ON,stage1)
$(call DEPENDS_ON,stage2)

S1PATCH_SRCS := s1patch.c
$(call add_host_executable,s1patch,$(S1PATCH_SRCS))

S2PATCH_SRCS := s2patch.c
$(call add_host_executable,s2patch,$(S2PATCH_SRCS))

TARGETS = fdimage

$(call local_target,prefdimage)_OUTPUT := prefdimage
$(call add_custom,prefdimage,)
$(call local_target,prefdimage)_SRCS := $(stage2_stage2_PATH)
$(call local_target,prefdimage)_TDEPS := $(call local_target,s2patch) 

QUIET_MKIMG = @echo 'MKIMG '$(call local_build,$@) &&
SILENT_MKIMG = @

STAGE1_START := $($(_MODULE_NAME)_OUTPUT)/stage1_start.txt
MKIMG := $(_MODULE_PATH)/makeimage.sh 
LIST_BLOCKS := $(_MODULE_PATH)/ext2_list_file_blocks.sh

ifneq ($($(_MODULE_NAME)_DEFINED),T)
$($(call local_target,prefdimage)_PATH) : $($(call local_target,prefdimage)_SRCS) $(call get_tpath,$($(call local_target,prefdimage)_TDEPS))
	$($(MODE)MKIMG)$(MKIMG) $@ $(STAGE1_START) $($(call local_target,s2patch)_PATH) $(LIST_BLOCKS) $(filter %.bin,$^)
endif

QUIET_S1PATCH = @echo 'S1PATCH '$(call local_build,$@) &&
SILENT_S1PATCH = @

$(call local_target,fdstage1)_OUTPUT := fdstage1.bin
$(call add_custom,fdstage1,)
$(call local_target,fdstage1)_SRCS := $(stage1_stage1_PATH) $(stage2_stage2_PATH)
$(call local_target,fdstage1)_TDEPS := $(call local_target,s1patch) $(call local_target,prefdimage)

ifneq ($($(_MODULE_NAME)_DEFINED),T)
$($(call local_target,fdstage1)_PATH) : $($(call local_target,fdstage1)_SRCS) $(call get_tpath,$($(call local_target,fdstage1)_TDEPS))
	$($(MODE)S1PATCH) $($(call local_target,s1patch)_PATH) $< $@ $(word 2,$^) FF `cat $(STAGE1_START)`
endif

QUIET_WRLDR = @echo 'WRLDR '$(call local_build,$@) &&
SILENT_WRLDR = @

$(call local_target,fdimage)_OUTPUT := fdimage
$(call add_custom,fdimage,)
$(call local_target,fdimage)_SRCS := $($(call local_target,fdstage1)_PATH)
$(call local_target,fdstage1)_TDEPS := $(call local_target,prefdimage)

ifneq ($($(_MODULE_NAME)_DEFINED),T)
$($(call local_target,fdimage)_PATH) : $($(call local_target,fdimage)_SRCS) $(call get_tpath,$($(call local_target,fdimage)_TDEPS)) 
	$(Q)cp $($(call local_target,prefdimage)_PATH) $@
	$($(MODE)WRLDR)cat $(filter %.bin,$^)|$(DD) of=$@ conv=notrunc 2>/dev/null
endif

# Magic footer, do not touch
include $(_ROOT)/suffix.mk
