
ifneq "$(findstring 3.7, $(MAKE_VERSION))" ""
ifeq "$(findstring 3.79.1, $(MAKE_VERSION))" ""
$(error GNU make version 3.79.1 or later is required.)
endif
endif

################################################################################
#
#	Layout of the source tree
#
################################################################################

# Here we provide defines for the various directories in the source tree,
# so we can move things around more easily.  A define $(GHC_FOO_DIR)
# indicates a directory relative to the top of the source tree.

GHC_UTILS_DIR           = utils
GHC_INCLUDE_DIR         = includes
GHC_COMPILER_DIR        = compiler
GHC_PROG_DIR            = ghc
GHC_RTS_DIR             = rts
GHC_DRIVER_DIR          = driver
GHC_COMPAT_DIR          = compat

GHC_LTX_DIR             = $(GHC_UTILS_DIR)/ltx
GHC_LNDIR_DIR           = $(GHC_UTILS_DIR)/lndir
GHC_MKDIRHIER_DIR       = $(GHC_UTILS_DIR)/mkdirhier
GHC_DOCBOOK_DIR         = $(GHC_UTILS_DIR)/docbook
GHC_UNLIT_DIR           = $(GHC_UTILS_DIR)/unlit
GHC_HP2PS_DIR           = $(GHC_UTILS_DIR)/hp2ps
GHC_GHCTAGS_DIR         = $(GHC_UTILS_DIR)/ghctags
GHC_HSC2HS_DIR          = $(GHC_UTILS_DIR)/hsc2hs
GHC_TOUCHY_DIR          = $(GHC_UTILS_DIR)/touchy
GHC_PKG_DIR             = $(GHC_UTILS_DIR)/ghc-pkg
GHC_GENPRIMOP_DIR       = $(GHC_UTILS_DIR)/genprimopcode
GHC_GENAPPLY_DIR        = $(GHC_UTILS_DIR)/genapply
GHC_CABAL_DIR           = $(GHC_UTILS_DIR)/ghc-cabal
GHC_SPLIT_DIR           = $(GHC_DRIVER_DIR)/split
GHC_SYSMAN_DIR          = $(GHC_RTS_DIR)/parallel

INPLACE                 = inplace
INPLACE_BIN             = $(INPLACE)/bin
INPLACE_LIB             = $(INPLACE)/lib
INPLACE_TOPDIR          = $(INPLACE)/lib
INPLACE_MINGW           = $(INPLACE)/mingw
INPLACE_PERL            = $(INPLACE)/perl

################################################################################
#
#    Bindist testing directory
#
################################################################################

BIN_DIST_INST_SUBDIR = "install dir"
BIN_DIST_INST_DIR = bindisttest/$(BIN_DIST_INST_SUBDIR)

################################################################################
#
#    rm
#
################################################################################

# These are here, rather than in config.mk, as they need to exist in an
# unconfigured tree so that the various clean targets can be used
# without configuring:
ifeq "$(ONLY_SHOW_CLEANS)" "YES"
RM = utils/testremove/wouldrm
RM_OPTS = CLEAN_FILES
RM_OPTS_REC = CLEAN_REC
else
RM = rm
RM_OPTS = -f
RM_OPTS_REC = -rf
endif

