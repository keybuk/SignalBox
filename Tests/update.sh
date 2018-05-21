#!/bin/sh

set -e
set -x

sourcery --sources Tests/ \
	--output Tests/ \
	--templates Tests/LinuxMain.stencil \
	--args testimports="\
@testable import DCCTests
@testable import OldDCCTests"
