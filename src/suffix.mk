$(_MODULE_NAME)_TARGETS := $(addprefix $(_MODULE_NAME)_,$(TARGETS))

ifneq ($(_NO_RULES),T)
ifneq ($($(_MODULE_NAME)_DEFINED),T)

_CLEAN := clean-$(_MODULE_NAME)
.PHONY: $(_CLEAN)
$(_CLEAN):
	$($(MODE)RM)$(RM) -r $($(patsubst clean-%,%,$@)_OUTPUT)

ifeq ($(_TOPLEVEL),$(_MODULE))
.PHONY: all clean
all: $($(_MODULE_NAME)_TARGETS)
clean: $(_CLEAN)
#$(info all: $($(_MODULE_NAME)_TARGETS))
#$(info clean: $(_CLEAN))
endif

.PHONY: $(_MODULE_NAME)
$(_MODULE_NAME): $($(_MODULE_NAME)_TARGETS) $(EXTRA_TARGETS)

_IGNORE := $(shell mkdir -p $($(_MODULE_NAME)_OUTPUT))

$($(_MODULE_NAME)_OUTPUT)/%$(_OBJ_EXT): $(_MODULE_PATH)/%.c $(LL_DEPS)
	$($(MODE)CC)$(CC) -MMD -MP -o $@ -c $(call c_include,$(INCLUDE_DIRS_C)) $(ALL_CFLAGS) $<

$($(_MODULE_NAME)_OUTPUT)/%$(_OBJ_EXT): $(_MODULE_PATH)/%.S $(LL_DEPS)
	$($(MODE)AS)$(AS) -c -o $@ $(call asm_include,$(INCLUDE_DIRS_ASM)) $(ALL_ASFLAGS) $<

$($(_MODULE_NAME)_OUTPUT)/%$(_OBJ_EXT): $(_MODULE_PATH)/%.asm $(LL_DEPS)
	$($(MODE)ASM)$(ASM) -MD $($(_MODULE_NAME)_OUTPUT)/$(<F:%.asm=%.d) -MP -o $@ $(ALL_ASFLAGS) $(call asm_include,$(INCLUDE_DIRS_ASM)) $<

$(info Finished reading $(_MODULE_NAME))

$(_MODULE_NAME)_DEFINED := T
endif
endif
