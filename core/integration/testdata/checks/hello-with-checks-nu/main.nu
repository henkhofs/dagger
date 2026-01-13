#!/usr/bin/env nu
# A module demonstrating @check functions in Nushell SDK

use /usr/local/lib/dag.nu *

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
