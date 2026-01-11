#!/usr/bin/env nu
# A module demonstrating @check functions in Nushell SDK

use nushell-sdk/runtime/runtime/dag/core.nu *
use nushell-sdk/runtime/runtime/dag/wrappers.nu *
use nushell-sdk/runtime/runtime/dag/container.nu *
use nushell-sdk/runtime/runtime/dag/directory.nu *
use nushell-sdk/runtime/runtime/dag/file.nu *
use nushell-sdk/runtime/runtime/dag/host.nu *

# @check
# A passing check - returns container that exits 0
export def "passing-check" []: nothing -> record {
    container from "alpine:3" | with-exec ["sh", "-c", "exit 0"]
}

# @check
# A failing check - returns container that exits 1
export def "failing-check" []: nothing -> record {
    container from "alpine:3" | with-exec ["sh", "-c", "exit 1"]
}
