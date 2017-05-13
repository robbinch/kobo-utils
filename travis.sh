#!/usr/bin/env bash
set -e
exec 2>&1

START=`date +%s`
export NIX_CURL_FLAGS=-sS
FORCE_REBUILD=0

get_nix_commit () {
 nix-instantiate --eval -E '(import <nixpkgs> {}).lib.nixpkgsVersion' | awk -F . '{print $NF}' | sed -e 's/"//g'
}

# setup cache or download nix
if [ "$1" == "setup" ]; then
  if [ "$FORCE_REBUILD" == 0 ] && [ -f $HOME/.cache/nix.tgz ]; then
    echo "Using cached Nix store..."
    sudo sh -c "mkdir -m 0755 /nix && chown $USER /nix"
    tar -C / -zxf $HOME/.cache/nix.tgz
    cp -d $HOME/.cache/.nix-profile $HOME
    cp -a $HOME/.cache/.nix-channels $HOME/.cache/.nix-defexpr $HOME
  else
    echo "Installing Nix..."
    wget --retry-connrefused --waitretry=1 -O /tmp/nix-install https://nixos.org/nix/install
    sh /tmp/nix-install
  fi
  source $HOME/.nix-profile/etc/profile.d/nix.sh
  echo "NIX_COMMIT: `get_nix_commit`"
  echo "GIT_COMMIT: `git rev-parse HEAD`"
  exit 0
fi

# if binary is already present, update channel
source $HOME/.nix-profile/etc/profile.d/nix.sh
NIX_COMMIT=`get_nix_commit`
GIT_COMMIT=`git rev-parse HEAD`
if [ -f "$HOME/.cache/dropbear.$NIX_COMMIT.$GIT_COMMIT" ]; then
  echo "Binary is up-to-date: `ls $HOME/.cache/dropbear.*`"
  rm -f $HOME/.cache.dropbear.* result
  nix-channel --update nixpkgs
fi

if [ "$1" == "dry-run" ]; then
  nix-build -A dropbear kobo.nix --dry-run 2>&1
  exit 0
fi

# build derivations persistently
REST=0
nix-build -A dropbear kobo.nix --dry-run 2>&1 | grep -E '\.drv$' | while read DRV; do
  ELAPSED=$((`date +%s`- $START))
  echo "Elapsed time: $ELAPSEDs"
  if [ "$ELAPSED" -gt 1800 ]; then
    echo "Resting for another day"
    REST=1
    break
  fi
  nix-store -r "$DRV"
done

# resting for another day
test "$REST" == 1 && exit 0

# if all derivations are built, check for linkage
BIN=result/bin/dropbear
if file "$BIN" | grep 'statically linked'; then
  cp "$BIN" "$HOME/.cache/dropbear.$NIX_COMMIT.$GIT_COMMIT"
else
  file "$BIN"
  echo "Binary built is not statically linked."
  exit 1
fi
