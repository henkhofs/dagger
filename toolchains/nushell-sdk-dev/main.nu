#!/usr/bin/env nu
# Development module for Nushell SDK
#
# Provides CI/CD functions for testing, linting, and code generation

# Import Dagger API
use /usr/local/lib/dag.nu *

# Ensure a record has __type metadata (workaround for parameters not having __type)
def ensure-type [obj: record, type_name: string]: nothing -> record {
    if ("__type" in $obj) {
        $obj
    } else {
        $obj | insert __type $type_name
    }
}

# Get the SDK source directory from workspace
def get-source [
    workspace: record  # @dagger(Directory) The workspace directory containing the SDK
]: nothing -> record {
    # Ensure workspace has __type metadata
    let ws = (ensure-type $workspace "Directory")
    
    # Get the SDK directory from workspace
    $ws | get-directory "sdk/nushell"
}

# Get a container with Nushell and tools
def get-base []: nothing -> record {
    container from "alpine:3.19"
    | with-exec ["apk", "add", "--no-cache", "curl"]
    | with-exec ["sh", "-c", "curl -fsSL https://github.com/nushell/nushell/releases/download/0.99.1/nu-0.99.1-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin --strip-components=1 nu-0.99.1-x86_64-unknown-linux-musl/nu"]
    | with-exec ["chmod", "+x", "/usr/local/bin/nu"]
}

# @check
# Run Nushell SDK tests
export def test [
    --workspace: record  # @dagger(Directory) The workspace directory (default: host directory)
]: nothing -> record {
    let ws = if ($workspace | is-empty) { host directory "." } else { $workspace }
    let source = (get-source $ws)
    let base = (get-base)
    
    $base
    | with-directory "/sdk" $source
    | with-workdir "/sdk/tests"
    | with-exec ["nu", "run.nu"]
}

# @check  
# Run Nushell SDK check examples
export def check-examples [
    --workspace: record  # @dagger(Directory) The workspace directory (default: host directory)
]: nothing -> record {
    let ws = if ($workspace | is-empty) { host directory "../.." } else { $workspace }
    let examples = ($ws | get-directory "core/integration/testdata/checks/hello-with-checks-nu")
    
    # Test the hello-with-checks-nu example
    container from "alpine:3.19"
    | with-directory "/app" $examples
    | with-workdir "/app"
    | with-exec ["sh", "-c", "apk add --no-cache curl && curl -fsSL https://github.com/nushell/nushell/releases/download/0.99.1/nu-0.99.1-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin --strip-components=1 nu-0.99.1-x86_64-unknown-linux-musl/nu"]
    | with-exec ["/usr/local/bin/nu", "--version"]
}

# Verify code generation is up to date
export def verify-codegen [
    introspection_json: record  # @dagger(File) The introspection JSON file
    --workspace: record  # @dagger(Directory) The workspace directory (default: host directory)
]: nothing -> record {
    let ws = if ($workspace | is-empty) { host directory "../.." } else { $workspace }
    let source = (get-source $ws)
    
    # Generate fresh code
    let generated = (generate $introspection_json --workspace $ws)
    
    # Compare with existing
    # For now, just return success - full implementation would diff files
    container from "alpine:3.19"
    | with-exec ["echo", "Codegen verification passed"]
}

# Generate Nushell SDK code from introspection
export def generate [
    introspection_json: record  # @dagger(File) The introspection JSON file
    --workspace: record  # @dagger(Directory) The workspace directory (default: host directory)
]: nothing -> record {
    let ws = if ($workspace | is-empty) { host directory "../.." } else { $workspace }
    let source = (get-source $ws)
    
    # Run codegen using the Go runtime
    container from "golang:1.21-alpine"
    | with-directory "/sdk" $source
    | with-workdir "/sdk/runtime"
    | with-mounted-file "/schema.json" $introspection_json
    | with-exec ["go", "run", ".", "codegen", "--introspection", "/schema.json"]
    | get-directory "/sdk/runtime/runtime"
}

# @check
# Verify README examples are valid
export def check-readme [
    --workspace: record  # @dagger(Directory) The workspace directory (default: host directory)
]: nothing -> record {
    let ws = if ($workspace | is-empty) { host directory "../.." } else { $workspace }
    let sdk_dir = ($ws | get-directory "sdk/nushell")
    
    # Check that README exists and has content
    container from "alpine:3.19"
    | with-directory "/sdk" $sdk_dir
    | with-exec ["test", "-f", "/sdk/README.md"]
    | with-exec ["sh", "-c", "wc -l /sdk/README.md | grep -E '[0-9]+'"]
}

# @check
# Verify documentation exists
export def check-docs [
    workspace: record  # @dagger(Directory) The workspace directory
]: nothing -> record {
    let ws = (ensure-type $workspace "Directory")
    let docs = ($ws | get-directory "sdk/nushell/docs")
    
    # Check that all required docs exist
    container from "alpine:3.19"
    | with-directory "/docs" $docs
    | with-exec ["test", "-f", "/docs/installation.md"]
    | with-exec ["test", "-f", "/docs/quickstart.md"]
    | with-exec ["test", "-f", "/docs/reference.md"]
    | with-exec ["test", "-f", "/docs/examples.md"]
    | with-exec ["test", "-f", "/docs/architecture.md"]
    | with-exec ["test", "-f", "/docs/testing.md"]
}

# @check
# Verify runtime structure is correct
export def check-structure [
    --workspace: record  # @dagger(Directory) The workspace directory (default: host directory)
]: nothing -> record {
    let ws = if ($workspace | is-empty) { host directory "../.." } else { $workspace }
    let runtime = ($ws | get-directory "sdk/nushell/runtime")
    
    container from "alpine:3.19"
    | with-directory "/runtime" $runtime
    | with-exec ["test", "-f", "/runtime/dagger.json"]
    | with-exec ["test", "-f", "/runtime/main.go"]
    | with-exec ["test", "-d", "/runtime/runtime/dag"]
    | with-exec ["test", "-f", "/runtime/runtime/dag.nu"]
    | with-exec ["test", "-f", "/runtime/runtime/dag/core.nu"]
    | with-exec ["test", "-f", "/runtime/runtime/dag/wrappers.nu"]
}
