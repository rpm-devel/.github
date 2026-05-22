#!/usr/bin/env bash
# entrypoint.sh — RPM build container startup
# Configures signing, validates mounts, then either runs a build or drops to shell.
#
# Environment variables:
#   RPM_GPG_KEY_ID          GPG key ID or email to sign with (optional — uses .rpmmacros default if unset)
#   RPM_SIGN_PASS_FILE      Path to passphrase file (default: /root/.gnupg/rpm_sign_pass.txt)
#   RPM_TARGET              mock config name to build against (e.g. almalinux-9-x86_64)
#                           When set, CMD must be a path to a .src.rpm file
#   RPM_OUTPUT_DIR          Directory to copy built RPMs into after a successful build
#                           (default: /root/Documents/builds)
set -euo pipefail

RPM_SIGN_PASS_FILE="${RPM_SIGN_PASS_FILE:-/root/.gnupg/rpm_sign_pass.txt}"
RPM_OUTPUT_DIR="${RPM_OUTPUT_DIR:-/root/Documents/builds}"

# ── Validate GPG passphrase file ──────────────────────────────────────────────
if [ -f "$RPM_SIGN_PASS_FILE" ]; then
  _perms=$(stat -c '%a' "$RPM_SIGN_PASS_FILE")
  if [ "$_perms" != "600" ]; then
    echo "entrypoint: WARNING: $RPM_SIGN_PASS_FILE has mode $_perms — should be 600" >&2
    chmod 600 "$RPM_SIGN_PASS_FILE"
  fi
else
  echo "entrypoint: WARNING: $RPM_SIGN_PASS_FILE not found — signing will be interactive" >&2
fi

# ── Override GPG key ID if supplied ───────────────────────────────────────────
if [ -n "${RPM_GPG_KEY_ID:-}" ]; then
  if [ -f /root/.rpmmacros ]; then
    # Replace existing _gpg_name line in place
    sed -i "s|^%_gpg_name .*|%_gpg_name ${RPM_GPG_KEY_ID}|" /root/.rpmmacros
  else
    echo "%_gpg_name ${RPM_GPG_KEY_ID}" >> /root/.rpmmacros
  fi
fi

# ── Non-interactive mock build ────────────────────────────────────────────────
if [ -n "${RPM_TARGET:-}" ]; then
  SRPM="${1:-}"
  if [ -z "$SRPM" ]; then
    echo "entrypoint: RPM_TARGET is set but no .src.rpm path given as CMD" >&2
    exit 2
  fi
  if [ ! -f "$SRPM" ]; then
    echo "entrypoint: source RPM not found: $SRPM" >&2
    exit 2
  fi

  echo "entrypoint: building $SRPM for $RPM_TARGET"
  \mock -r "$RPM_TARGET" --rebuild "$SRPM"

  # Copy results out
  _result_dir="/var/lib/mock/${RPM_TARGET}/result"
  if [ -d "$_result_dir" ]; then
    _out="${RPM_OUTPUT_DIR}/${RPM_TARGET}"
    mkdir -p "$_out"
    \cp "$_result_dir"/*.rpm "$_out/" 2>/dev/null || true
    echo "entrypoint: RPMs written to $_out"
  fi
  exit 0
fi

# ── Interactive / pass-through ────────────────────────────────────────────────
exec "$@"
