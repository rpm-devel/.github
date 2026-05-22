#!/usr/bin/env bash
# entrypoint.sh — RPM build container startup
# Configures signing, validates mounts, then either runs a build or drops to shell.
#
# Environment variables:
#   RPM_GPG_KEY_ID          GPG key ID or email to sign with (optional — uses .rpmmacros default if unset)
#   RPM_SIGN_PASS_FILE      Path to passphrase file (default: /root/.gnupg/rpm_sign_pass.txt)
#   RPM_TARGET              mock config name to build against (e.g. almalinux-9-x86_64)
#                           EOL targets use the eol/ prefix (e.g. eol/centos-7-x86_64)
#                           When set, CMD must be a path to a .spec or .src.rpm file.
#                           .spec  — sources are downloaded with spectool, a SRPM is
#                                    built with rpmbuild -bs, then mock rebuilds it.
#                           .src.rpm — passed directly to mock --rebuild.
#   RPM_OUTPUT_DIR          Directory to copy built RPMs into after a successful build
#                           (default: /root/Documents/builds)
#
# EOL targets (eol/ prefix) are treated identically to current targets — build failures
# are always hard errors (exit 1). EOL simply means the repos have moved to an archive
# location; security and bug-fix builds for EOL releases are still fully supported.
# The EOL configs in this image override mock-core-configs to use the correct
# archive URLs (archives.fedoraproject.org, vault.centos.org) rather than live mirrors.
set -euo pipefail

RPM_SIGN_PASS_FILE="${RPM_SIGN_PASS_FILE:-/root/.gnupg/rpm_sign_pass.txt}"
RPM_OUTPUT_DIR="${RPM_OUTPUT_DIR:-/root/Documents/builds}"

# ── Validate GPG passphrase file ──────────────────────────────────────────────
if [ -f "$RPM_SIGN_PASS_FILE" ]; then
  _perms=$(stat -c '%a' "$RPM_SIGN_PASS_FILE")
  if [ "$_perms" != "600" ]; then
    echo "entrypoint: WARNING: $RPM_SIGN_PASS_FILE has mode $_perms — should be 600" >&2
    \chmod 600 "$RPM_SIGN_PASS_FILE"
  fi
else
  echo "entrypoint: WARNING: $RPM_SIGN_PASS_FILE not found — signing will be interactive" >&2
fi

# ── Override GPG key ID if supplied ───────────────────────────────────────────
if [ -n "${RPM_GPG_KEY_ID:-}" ]; then
  if [ -f /root/.rpmmacros ]; then
    \sed -i "s|^%_gpg_name .*|%_gpg_name ${RPM_GPG_KEY_ID}|" /root/.rpmmacros
  else
    echo "%_gpg_name ${RPM_GPG_KEY_ID}" >> /root/.rpmmacros
  fi
fi

# ── Non-interactive mock build ────────────────────────────────────────────────
if [ -n "${RPM_TARGET:-}" ]; then
  INPUT="${1:-}"
  if [ -z "$INPUT" ]; then
    echo "entrypoint: RPM_TARGET is set but no .spec or .src.rpm path given as CMD" >&2
    exit 2
  fi
  if [ ! -f "$INPUT" ]; then
    echo "entrypoint: file not found: $INPUT" >&2
    exit 2
  fi

  case "$INPUT" in
    *.spec)
      echo "entrypoint: downloading sources for $INPUT"
      if ! \spectool -g -R "$INPUT"; then
        echo "entrypoint: ERROR: spectool failed for $INPUT" >&2
        exit 1
      fi

      echo "entrypoint: building SRPM from $INPUT"
      _rpmbuild_out=$(\rpmbuild -bs "$INPUT" 2>&1)
      echo "$_rpmbuild_out"
      SRPM=$(echo "$_rpmbuild_out" | \grep '^Wrote:' | \awk '{print $2}')
      if [ -z "$SRPM" ] || [ ! -f "$SRPM" ]; then
        echo "entrypoint: ERROR: could not locate built SRPM" >&2
        exit 1
      fi
      echo "entrypoint: built SRPM: $SRPM"
      ;;
    *.src.rpm)
      SRPM="$INPUT"
      ;;
    *)
      echo "entrypoint: ERROR: CMD must be a .spec or .src.rpm file, got: $INPUT" >&2
      exit 2
      ;;
  esac

  echo "entrypoint: building $SRPM for $RPM_TARGET"
  if ! \mock -r "$RPM_TARGET" --rebuild "$SRPM"; then
    echo "entrypoint: ERROR: build failed for $RPM_TARGET" >&2
    exit 1
  fi

  # Copy results out — never removes existing RPMs, only adds new ones
  _result_dir="/var/lib/mock/${RPM_TARGET}/result"
  if [ -d "$_result_dir" ]; then
    _out="${RPM_OUTPUT_DIR}/${RPM_TARGET}"
    \mkdir -p "$_out"
    \cp "$_result_dir"/*.rpm "$_out/" 2>/dev/null || true
    echo "entrypoint: RPMs written to $_out"
  fi
  exit 0
fi

# ── Interactive / pass-through ────────────────────────────────────────────────
exec "$@"
