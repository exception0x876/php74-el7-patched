#!/usr/bin/env bash
#
# Rebuild the patched PHP 7.4.33-31 RPMs for EL7 (CentOS 7) from Remi's SRPM.
#
# Requirements: Docker (linux/amd64), ~15 GB free Docker disk, 12+ GB RAM recommended,
# 30-60 minutes (the PHP test suite runs as part of the build).
#
# Steps:
#   1. download Remi's SRPM and check its SHA-256
#   2. verify its GPG signature against a pinned key fingerprint (AlmaLinux 9
#      container: rpm 4.11 on CentOS 7 cannot read this SRPM)
#   3. extract it and apply the two patches from ../patches
#   4. build in a clean centos:7 container (see inside.sh)
#
# Output: ./out-rebuild/*.rpm and ./out-rebuild/*.src.rpm (override with OUT_DIR=/path)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD
WORK=$ROOT/work
OUT=${OUT_DIR:-$ROOT/out-rebuild}   # never the release staging dir ./out

SRPM_NAME=php-7.4.33-31.remi.src.rpm
SRPM_URL=https://rpms.remirepo.net/SRPMS/$SRPM_NAME
SRPM_SHA256=89aed65aea684fff577a8adaa37aba6db6b818b917f02d792c265b41f75af8ee
REMI_KEY_URL=https://rpms.remirepo.net/RPM-GPG-KEY-remi2026
REMI_KEY_FPR=2E375FE24EDFF0F2E0D8E165ED5B58C5BEFA00E2

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

mkdir -p "$WORK/src" "$OUT"

echo "==> 1/4 download SRPM"
[ -f "$WORK/$SRPM_NAME" ] || curl -fsSL -o "$WORK/$SRPM_NAME" "$SRPM_URL"
got=$(sha256 "$WORK/$SRPM_NAME")
if [ "$got" != "$SRPM_SHA256" ]; then
  echo "SRPM SHA-256 mismatch: expected $SRPM_SHA256, got $got" >&2
  exit 1
fi

echo "==> 2/4 verify signature, extract, patch"
docker run --rm --platform linux/amd64 \
  -e REMI_KEY_URL="$REMI_KEY_URL" -e REMI_KEY_FPR="$REMI_KEY_FPR" -e SRPM_NAME="$SRPM_NAME" \
  -v "$WORK":/work -v "$ROOT/patches":/patches:ro \
  almalinux:9 bash -euc '
    dnf -y -q install cpio patch gnupg2 >/dev/null   # curl-minimal is already in the image
    curl -fsSL -o /tmp/remi.key "$REMI_KEY_URL"
    fpr=$(gpg --show-keys --with-colons /tmp/remi.key | awk -F: "\$1==\"fpr\"{print \$10; exit}")
    [ "$fpr" = "$REMI_KEY_FPR" ] || { echo "Remi key fingerprint mismatch: $fpr" >&2; exit 1; }
    rpm --import /tmp/remi.key
    rpm -Kv /work/"$SRPM_NAME" | tee /tmp/k.txt
    grep -q "key ID befa00e2: OK" /tmp/k.txt || { echo "SRPM signature not verified" >&2; exit 1; }
    cd /work/src
    rpm2cpio /work/"$SRPM_NAME" | cpio -idm --quiet
    for p in /patches/*.patch; do echo "applying $p"; patch -p1 < "$p"; done
  '

echo "==> 3/4 build in centos:7 (long)"
docker run --rm --platform linux/amd64 \
  -v "$WORK/src":/srpm:ro -v "$OUT":/out -v "$ROOT/build/inside.sh":/inside.sh:ro \
  centos:7 bash /inside.sh

echo "==> 4/4 done"
ls -l "$OUT"
