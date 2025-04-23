# FastWrt terminal color definitions

# Define terminal colors
set -g green (echo -e "\033[0;32m")
set -g yellow (echo -e "\033[0;33m")
set -g red (echo -e "\033[0;31m")
set -g blue (echo -e "\033[0;34m")
set -g purple (echo -e "\033[0;35m")
set -g cyan (echo -e "\033[0;36m")
set -g white (echo -e "\033[0;37m")
set -g reset (echo -e "\033[0m")

# Define color usage functions
function print_info
    echo "$blue""$argv""$reset"
end

function print_success
    echo "$green""$argv""$reset"
end

function print_warning
    echo "$yellow""$argv""$reset"
end

function print_error
    echo "$red""$argv""$reset"
end

function print_header
    echo "$purple""$argv""$reset"
end

function print_debug
    if test "$DEBUG" = "true"
        echo "$cyan""$argv""$reset"
    end
end
