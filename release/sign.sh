#!/usr/bin/env bash
#
# Run this on YOUR machine, where the signing key lives. It never leaves the machine.
# Creates out/SHA256SUMS and a detached, armored signature out/SHA256SUMS.asc, then verifies it.
set -euo pipefail

KEY=CA0986107910D598A3EF28DBEFCFD009B4137B36
cd "$(dirname "$0")/../out"

ls ./*.rpm >/dev/null
if command -v sha256sum >/dev/null; then SUM=sha256sum; else SUM="shasum -a 256"; fi
$SUM ./*.rpm | sed 's#  \./#  #' | sort -k2 > SHA256SUMS
echo "$(wc -l < SHA256SUMS) files in SHA256SUMS"

gpg --local-user "$KEY" --armor --detach-sign --yes --output SHA256SUMS.asc SHA256SUMS
gpg --verify SHA256SUMS.asc SHA256SUMS
echo "Signed with: $(gpg --list-keys --with-colons "$KEY" | awk -F: '$1=="fpr"{print $10; exit}')"
