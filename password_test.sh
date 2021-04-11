#!/usr/bin/env bash

set -euo pipefail

prog=$(basename "$0")

print_usage() {
    echo "$prog"
    echo
    echo '  -h, --help      print this help text and exit'
    echo '  -q, --quiet     suppress non-essential output'
    echo
}

prompt() {
    if [ -z "$quiet" ]; then
        echo
        echo -n 'Ketiklah Password Anda dan klik enter (biarkan kosong untuk keluar dari program ini)': 
    fi
}

wipe_password_var() {
    
    password=$(head -c 256 /dev/urandom | tr '\0' 'x')
    unset password
}

check_if_pwned() {
    
    local password_hash
    local hash_prefix
    local hash_suffix
    local count
    password_hash=$(printf "%s" "$password" | openssl sha1 | awk '{print $NF}')

    wipe_password_var

    hash_prefix=$(echo "$password_hash" | cut -c -5)
    hash_suffix=$(echo "$password_hash" | cut -c 6-)

    if [ -z "$quiet" ]; then
        echo "Hash prefix: $hash_prefix"
        echo "Hash suffix: $hash_suffix"
        echo
        echo 'Mencari Kata Sandi Anda...'
    fi

    response=$(curl -fsS "https://api.pwnedpasswords.com/range/$hash_prefix")

    count=$(echo "$response" \
            | grep -i "$hash_suffix" \
            | cut -d':' -f2 \
            | grep -Eo '[0-9]+' \
            || echo 0)

    if [ -z "$quiet" ]; then
        echo "Password anda terlihat di database the Pwned Passwords Sebanyak $count kali(detik)."

        if [ "$count" -ge 100 ]; then
            echo 'Password ini sangat sering diretas! JANGANLAH GUNAKAN PASSWORD INI DENGAN ALASAN APAPUN!'
        elif [ "$count" -ge 20 ]; then
            echo 'Password ini pernah diretas dan terlihat di beberapa database! sebaiknya anda tidak mengunakan password ini dan buatlah password baru yang lebih kuat!'
        elif [ "$count" -gt 0 ]; then
            echo 'Password ini terlihat pernah diretas tetapi tidak terlihat dimana mana, gunakan password ini dengan resiko anda sendiri !'
        elif [ "$count" -eq 0 ]; then
            echo "Password ini terlihat tidak pernah diretas/dicrack, tapi bukan berarti password ini  aman dan tidak dapat diretas "
        fi
    else
        echo "$password_hash    $count"
    fi

}

trap wipe_password_var EXIT

quiet=
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -q|--quiet)
            quiet=yes
            ;;
        *)
            print_usage
            echo "Unrecognized argument: '$arg'"
            echo 'Note: For security reasons, this script no longer accepts passwords via command-'
            echo 'line arguments. Please use the prompt or pipe a file into this script.'
            exit 1
            ;;
    esac
done

if [ -z "$quiet" ]; then
    echo
    echo 'probabilitas password pernah diretas'
    echo 'PROGRAM INI TIDAK UNTUK MENGHITUNG KEKUATAN PASSWORD ANDA!'
fi
prompt

while read -r -s password; do
    [ -n "$password" ] || exit 0
    [ -n "$quiet" ] || echo
    check_if_pwned
    prompt
done < /dev/stdin
