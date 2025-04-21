#!/bin/sh

# Make scripts executable
chmod -R +x ./scripts/*.sh

# Detect the current shell and switch to fish if needed
current_shell=$(ps -p $$ -o comm=)
echo "Current shell: $current_shell"

if [ "$current_shell" != "fish" ]; then
    echo "Not running in fish shell, will execute install.sh with fish..."
    if command -v fish >/dev/null 2>&1; then
        exec fish -c "./install.sh"
    else
        echo "Fish shell not found. Please install fish or run this script from fish shell."
        exit 1
    fi
else
    echo "Already running in fish shell, executing install.sh directly..."
    ./install.sh
fi