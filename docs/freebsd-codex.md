# Codex on FreeBSD

These notes describe the steps used to upgrade Codex on the FreeBSD laptop after the VS Code Codex extension reported that `gpt-5.5` required a newer Codex version.

## Goal

Install a newer Codex CLI on FreeBSD so both the terminal and VS Code extension can use the current model configuration.

## What Worked

The normal upstream installer was not enough on FreeBSD. The official installer supports macOS and Linux, but not FreeBSD, and the packaged FreeBSD Codex version was older than the version required by the extension.

The successful path was to build the newer FreeBSD `misc/codex` port locally.

## Steps Performed

1. Checked the installed version:

   ```sh
   codex --version
   pkg info -x "^codex-"
   ```

   The laptop had `codex-0.117.0`.

2. Checked the official Codex install path.

   The installer did not support FreeBSD directly.

3. Tried building Codex directly from upstream source.

   That failed because the V8 Rust dependency tried to download a prebuilt FreeBSD archive that did not exist.

4. Checked FreeBSD ports.

   The `misc/codex` port had already been updated to `0.139.0` and included the FreeBSD-specific setup needed to build V8 from source.

5. Created a sparse ports checkout under:

   ```text
   /tmp/freebsd-ports
   ```

6. Installed build dependencies, including Rust, LLVM, Ninja, and GN.

7. Found the packaged `gn` was too old for the current V8 build.

   Built and installed newer `gn-2345` from ports.

8. Built Codex from the `misc/codex` port with V8 from source.

   This was the long step: V8 compiled first, then the Codex Rust crates, then the final optimized `codex` binary.

9. Installed the finished port over the old package:

   ```text
   codex-0.117.0 -> codex-0.139.0
   ```

10. Verified the active version:

    ```text
    codex-cli 0.139.0
    codex-0.139.0
    ```

## Key Detail

Use the FreeBSD port instead of raw upstream source. The port knows how to build V8 locally on FreeBSD, while the raw upstream source path tries to use a prebuilt V8 artifact that is not available for FreeBSD.

After upgrading, restart VS Code or run `Developer: Reload Window` so the Codex extension picks up the upgraded `/usr/local/bin/codex`.
