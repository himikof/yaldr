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

TARGETS = fdimage

QUIET_S1PATCH = @echo 'S1PATCH '$(call local_build,$@) &&
SILENT_S1PATCH = @

$(call local_target,fdstage1)_OUTPUT := fdstage1.bin
$(call add_custom,fdstage1,)
$(call local_target,fdstage1)_SRCS := $(stage1_stage1_PATH) $(stage2_stage2_PATH)
$(call local_target,fdstage1)_TDEPS := $(call local_target,s1patch)

ifneq ($($(_MODULE_NAME)_DEFINED),T)
$($(call local_target,fdstage1)_PATH) : $($(call local_target,fdstage1)_SRCS) $(call get_tpath,$($(_TN)_TDEPS))
	$($(MODE)S1PATCH) $(tools_s1patch_PATH) $< $@ $(word 2,$^)
endif

QUIET_FDIMG = @echo 'FDIMG '$(call local_build,$@) &&
SILENT_FDIMG = @

$(call local_target,fdimage)_OUTPUT := fdimage
$(call add_custom,fdimage,)
$(call local_target,fdimage)_SRCS := $($(call local_target,fdstage1)_PATH) $(stage2_stage2_PATH)

ifneq ($($(_MODULE_NAME)_DEFINED),T)
$($(call local_target,fdimage)_PATH) : $($(call local_target,fdimage)_SRCS) $(call get_tpath,$($(_TN)_TDEPS)) 
	$($(MODE)FDIMG)$(DD) if=/dev/zero of=$@ count=2880 2>/dev/null
	$(Q)cat $(filter %.bin,$^)|$(DD) of=$@ conv=notrunc 2>/dev/null
endif

# Magic footer, do not touch
include $(_ROOT)/suffix.mk
