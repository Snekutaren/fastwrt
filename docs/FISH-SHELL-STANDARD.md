# Fish Shell Standard for FastWrt

## Overview

FastWrt standardizes on using the Fish shell (`fish`) for all scripts and automated configuration. This document explains the reasoning behind this decision and provides guidelines for developing fish-compatible scripts.

## Why Fish Shell?

1. **Consistent Environment**: Fish is installed by default in FastWrt, ensuring a consistent execution environment for all scripts.

2. **Modern Features**: Fish provides superior syntax highlighting, autocompletion, and user-friendly syntax that reduces errors.

3. **Error Prevention**: Fish's stricter syntax helps prevent common shell scripting errors that can occur in bash/ash.

4. **Script Integration**: By standardizing on fish, all scripts can easily call other scripts and share environment variables consistently.

5. **Better String Handling**: Fish provides better string handling capabilities, which is crucial for manipulating configuration files.

## Implementation Guidelines

### 1. Script Headers

All scripts should begin with:

```fish
#!/usr/bin/fish
# Script name - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts
```

### 2. Variable Declaration

Use fish's variable declaration syntax:

```fish
# Traditional shell:
# VARIABLE=value

# Fish shell:
set variable value
```

### 3. Environment Variables

For environment variables:

```fish
set -gx VARIABLE value   # Global, exported (environment) variable
set -g VARIABLE value    # Global variable (for current fish session)
set -l VARIABLE value    # Local variable (for current block/function)
```

### 4. Conditional Statements

Fish uses a cleaner syntax for conditions:

```fish
if test "$variable" = "value"
    # commands
else if test "$variable" = "other_value"
    # commands
else
    # commands
end
```

### 5. Loops

Fish loops are more intuitive:

```fish
# For loop example
for item in $items
    echo "Processing $item"
end

# While loop example
while test $count -lt 10
    set count (math $count + 1)
end
```

### 6. Function Declaration

```fish
function function_name
    # function code
end
```

### 7. Command Substitution

Use parentheses for command substitution:

```fish
# Traditional shell: $(command)
# Fish shell:
set result (command)
```

### 8. Script Execution

When running another script:

```fish
fish /path/to/script.fish
```

### 9. Error Handling

Fish has more consistent error handling:

```fish
if not command
    echo "Command failed"
    exit 1
end
```

## Migration Notes

When converting bash/ash scripts to fish:

1. Replace `$variable` with `$variable` (same syntax)
2. Replace `$(command)` with `(command)`
3. Replace `VAR=value` with `set VAR value`
4. Replace `if [ condition ]; then` with `if test condition`
5. Replace `fi` with `end`
6. Replace `&&` and `||` with `; and` and `; or`

## Tools and Resources

- Fish shell documentation: https://fishshell.com/docs/current/
- Fish script lint checker: https://github.com/fish-shell/fish-shell/tree/master/share/tools

By following these standards, we ensure that all FastWrt scripts are consistent, maintainable, and leverage the advantages of the fish shell.

Last Updated: April 25, 2025
