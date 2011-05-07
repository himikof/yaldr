# Yaldr stage2

# Magic header. Can't touch it!
sp :=
sp +=
_walk = $(if $1,$(wildcard /$(subst $(sp),/,$1)/$2) $(call _walk,$(wordlist 2,$(words $1),x $1),$2))
_find = $(firstword $(call _walk,$(strip $(subst /, ,$1)),$2))
_ROOT ?= $(patsubst %/root.mk,%,$(call _find,$(CURDIR),root.mk))
include $(_ROOT)/root.mk
include $(_ROOT)/prefix.mk
# End of magic


STAGE2_SRCS = main.asm mem.asm
$(call local_target,pre-stage2)_LDSCRIPT = $(_MODULE_PATH)/stage2.ld
$(call add_executable,pre-stage2,$(STAGE2_SRCS))

$(call local_target,stage2)_TDEPS := $(call local_target,pre-stage2)
$(call add_binary,stage2,)

TARGETS = stage2

# Magic footer, do not touch
include $(_ROOT)/suffix.mk
