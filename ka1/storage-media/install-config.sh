#!/usr/bin/env bash

SCRIPT_PATH=$(dirname "$(realpath $0)")
FILE="/etc/nixos/configuration.nix"

echo "Checking if configuration.nix already exists ..."
if [ -f "$FILE" ] || [ -L "$FILE" ]; then
	read -p "configuration.nix already exists. Overwrite? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
	    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
	fi
	echo "Removing old configurations.nix ..."
	rm -f /etc/nixos/configuration.nix
fi

echo "Installing new configuration.nix ..."
ln -s "$SCRIPT_PATH/configuration.nix" /etc/nixos/configuration.nix

echo "New configuration.nix installed!"

