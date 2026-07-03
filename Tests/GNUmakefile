#
#  Tests Makefile for the GNUstep Backend.
#
#  Copyright (C) 2026 Free Software Foundation, Inc.
#
#  This file is part of the GNUstep Backend.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, see <http://www.gnu.org/licenses/> or write to the
#  Free Software Foundation, 51 Franklin Street, Fifth Floor,
#  Boston, MA 02110-1301, USA.
#

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before running this!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

# Backend regression tests use the gnustep-make test framework.  Each backend
# keeps its tests in a subdirectory named for its Source/ directory (cairo,
# x11, ...), marked by a TestInfo file.  Discover every such subdirectory and
# run them all, so a new backend's tests are picked up automatically with no
# change to this makefile.  Each test additionally guards itself -- in its
# source (via config.h) and its GNUmakefile.preamble (via config.make) -- on
# the backend actually built, so 'make check' works for any configuration:
# tests for backends that are not built skip themselves cleanly.
TEST_SUBDIRS := $(sort $(patsubst %/TestInfo,%,$(wildcard */TestInfo)))

all::
	@(echo If you want to run the gnustep-back testsuite, please type \'$(MAKE) check\')

check::
	(\
	if [ -z "$(TEST_SUBDIRS)" ]; then \
	  echo "No backend test directories found; nothing to check.";\
	elif [ "$(debug)" = "yes" ]; then \
	  gnustep-tests --debug --timeout 300 $(TEST_SUBDIRS);\
	else \
	  gnustep-tests --timeout 300 $(TEST_SUBDIRS);\
	fi; \
	)

clean::
	-gnustep-tests --clean

include $(GNUSTEP_MAKEFILES)/rules.make
