_OUTPUT_ROOT ?= $(abspath $(_ROOT)/../build)

.PHONY: all
all:

_MAKEFILES := $(filter %/Makefile,$(MAKEFILE_LIST))
_INCLUDED_FROM := $(patsubst $(_ROOT)/%,%,$(if $(_MAKEFILES),$(patsubst %/Makefile,%,$(word $(words $(_MAKEFILES)),$(_MAKEFILES)))))
ifeq ($(_INCLUDED_FROM),)
_MODULE := $(patsubst $(_ROOT)/%,%,$(CURDIR))
_TOPLEVEL := $(_MODULE)
else
_MODULE := $(_INCLUDED_FROM)
endif
_MODULE_PATH := $(_ROOT)/$(_MODULE)
_MODULE_NAME := $(subst /,_,$(_MODULE))
$(_MODULE_NAME)_OUTPUT := $(_OUTPUT_ROOT)/$(_MODULE)

#OUTDIR := $($(_MODULE_NAME)_OUTPUT)

_OBJ_EXT := .o
_LIB_EXT := .lib.o
_EXE_EXT :=
_HOSTEXE_EXT :=
_BIN_EXT := .bin

tpl = $(call _PREFIX_TPL,$(2),$(3))$(call $(1)_TPL,$(2),$(3))
add_target = $(if $($(_MODULE_NAME)_DEFINED),,$(eval $(call tpl,$(1),$(2),$(3))))
add_library = $(call add_target,LIBRARY,$(1),$(2))
add_executable = $(call add_target,EXECUTABLE,$(1),$(2))
add_host_executable = $(call add_target,HOST_EXECUTABLE,$(1),$(2))
add_binary = $(call add_target,BINARY,$(1),$(2))
add_all_library = $(eval $(_MODULE_NAME)_all_TDEPS := $(addsuffix _all,$(addprefix $(_MODULE_NAME)_,$($(_MODULE_NAME)_SUBTARGETS))))$(call add_library,all,)
add_custom = $(call add_target,CUSTOM,$(1),$(2))

c_include = $(addprefix -I ,$(1))
asm_include = $(addprefix -I,$(1))

local_target = $(_MODULE_NAME)_$(1)
local_src = $(subst $(_ROOT)/,,$(abspath $(1)))
local_build = $(subst $(_OUTPUT_ROOT)/,,$(abspath $(1)))

get_tpath = $(foreach t,$(1),$($(t)_PATH))

set_subtargets = $(eval $(_MODULE_NAME)_SUBTARGETS := $(1))$(foreach st,$(1),$(call DEPENDS_ON,$(_MODULE)/$(st)))

ifneq ($($(_MODULE_NAME)_DEFINED),T)
$(info Reading module $(_MODULE)...)
endif
