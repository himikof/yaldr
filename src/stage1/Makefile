# Yaldr stage1

# Magic header, do not touch
sp :=
sp +=
_walk = $(if $1,$(wildcard /$(subst $(sp),/,$1)/$2) $(call _walk,$(wordlist 2,$(words $1),x $1),$2))
_find = $(firstword $(call _walk,$(strip $(subst /, ,$1)),$2))
_ROOT ?= $(patsubst %/root.mk,%,$(call _find,$(CURDIR),root.mk))
include $(_ROOT)/root.mk
include $(_ROOT)/prefix.mk
# End of magic


STAGE1_SRCS = boot.asm util.asm
$(call local_target,pre-stage1)_LDSCRIPT = $(_MODULE_PATH)/boot.ld
$(call add_executable,pre-stage1,$(STAGE1_SRCS))

$(call local_target,stage1)_TDEPS := $(call local_target,pre-stage1)
$(call add_binary,stage1,)

TARGETS = stage1

# Magic footer, do not touch
include $(_ROOT)/suffix.mk
