# FastWrt Script Conventions

## File Extensions

Although all scripts in the FastWrt project are written in the Fish shell language, we maintain the `.sh` extension for the following reasons:

1. **OpenWrt Compatibility**: The OpenWrt UCI-defaults mechanism specifically looks for `.sh` files in the `/etc/uci-defaults/` directory, regardless of their internal syntax.

2. **System Integration**: Many system processes expect shell scripts to have the `.sh` extension, and changing this could cause compatibility issues.

3. **Execution Pattern**: The shebang line (`#!/usr/bin/fish`) at the top of each script ensures they're executed with the fish interpreter regardless of extension.

## Alternative Approach

For clarity, we use the following conventions to make it obvious these are Fish scripts:

1. **Shebang Line**: All scripts begin with `#!/usr/bin/fish` to clearly indicate the interpreter.

2. **Comment Header**: Each script includes a comment specifying "Fish implementation" in the description.

3. **Consistent Syntax**: All scripts use pure Fish syntax (not Bash) with Fish-style conditionals, loops, and variable handling.

## Directory Organization

We maintain all script files in their appropriate directories according to their function, not their language:

- `scripts/etc/uci-defaults/` - Scripts executed at first boot
- `scripts/helpers/` - Helper scripts for maintenance tasks

## Documentation

Always document in comments when a fish-specific feature is being used, especially if it differs significantly from traditional shell syntax.

## Future Consideration

If OpenWrt adds native support for recognizing `.fish` extension files in the future, we may revisit this convention.

---

Last Updated: April 25, 2025
