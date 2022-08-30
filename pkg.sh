#!/bin/bash

#   Title: pkg.sh
#    Desc: Build packages with makepkg wrapped around upgrades and snapshots
#  Author: Juan D Frias <juandfrias@gmail.com>
# License: CC BY-SA 4.0  <https://creativecommons.org/licenses/by-sa/4.0/>
#
# Version: 1.0.0
# Created: 2022 Aug 23
# Updated: 2022 Aug 30

set -o errexit
set -o nounset
set -o pipefail


PACMAN=/usr/bin/pacman
SNAPPER=/usr/bin/snapper
MAKEPKG=/usr/bin/makepkg
NEWS_FEED="https://archlinux.org/feeds/news/"


function error() {
    printf '\e[31mERROR: %s\e[0m\n' "$*" >&2
}

function log() {
    printf '\e[32m%s\e[0m\n' "$*"
}

function ask() {
    printf '\n\e[1;33m%s\e[0m ' "$*"
    read input
    echo ''
}

function usage() {
    cat <<EOF
Pkg v1.0.0 - Build local packages

Usage:
  pkg [options] <build dir>

Options:
  --help                         Usage help
  --skip-upgrade, -k             Skip system upgrade
  ---pre-snapshot-num, -p <NUM>  Don't take pre-snapshot use specified one

EOF
}


snapshot_pre_num=
skip_upgrade=0
pkg_path=
pkg_name=

# parse args
while (( "$#" )); do
    case "$1" in
        --pre-snapshot-num|-p)
            if [ "${2:-}" = "" ]; then
                error "Must specify pre snapshot number to use"
                exit 1
            fi
            snapshot_pre_num=$2
            shift 2
            ;;

        --skip-upgrade|-k)
            skip_upgrade=1
            shift
            ;;

        --help)
            usage
            exit 0
            ;;

        -*)
            usage
            error "Invalid command line option \"$1\""
            exit 1
            ;;

        *)
            if [ "$pkg_path" != "" ]; then
                error "Can only build one package at a time"
                exit 1
            fi
            pkg_path=$(echo "${1%/}")
            pkg_name=$(basename "$pkg_path")
            shift
            ;;
    esac
done


# check a package was specified
if [ "$pkg_path" = "" ]; then
    usage
    exit 1
fi


# fetch news on system upgrade
if [ "$skip_upgrade" -ne 1 ]; then
    log "Fetching latest Arch News..."
    curl --silent "$NEWS_FEED" | unidecode | xml sel -t -m //item -v pubDate -o " | " -v title -n

    # continue with upgrade?
    ask "Continue? (Y/n)"
    if [[ "$input" = "N" || "$input" = "n" ]]; then
        exit 0
    fi
fi


# take a system snapshot, if pre not specified
if [ "$snapshot_pre_num" = "" ]; then
    log "Taking pre-install snapshot..."
    snapshot_pre_num=$(sudo "$SNAPPER" --config root create --type pre --print-number \
        --description "Pre-install $pkg_name" --userdata created_by=pkg,important=yes)
    log "Created snapshot #$snapshot_pre_num."
else
    log "Using pre snapshot #$snapshot_pre_num."
fi


# do system upgrade
if [ "$skip_upgrade" -ne 1 ]; then
    log "Upgrading system..."
    # force repo refresh with extra -y
    sudo "$PACMAN" --sync --refresh -y --sysupgrade "$@" || {
        echo ""
        sudo "$SNAPPER" --config root list
        error "Someting doesn't look right, keeping pre snapshot #$snapshot_pre_num."
        exit 1
    }
fi


# building and installing new package
cd "$pkg_path"
"$MAKEPKG" --force --syncdeps --install --clean --rmdeps --needed || {
    echo ""
    sudo "$SNAPPER" --config root list
    error "Someting went wrong with the build, keeping snapshot #$snapshot_pre_num."
    exit 1
}


# everyting went a-OK, create a post snapshot
log "Taking post install snapshot..."
sudo "$SNAPPER" --config root create --type post --pre-number "$snapshot_pre_num" \
    --description "Post-install $pkg_name" --userdata created_by=pkg,important=yes


# update grub
log "Updating grub with latest snapshots..."
sudo grub-mkconfig -o /boot/grub/grub.cfg


log "Done."

