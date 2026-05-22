# rpm-devel

RPM packaging organization for [CasjaysDev](https://github.com/casjaysdev). Builds signed RPM packages for RHEL/AlmaLinux (EL7–EL10) and Fedora (36+), distributed via a self-hosted DNF repository on SourceForge.

## Package Repo Layout

Every package lives in its own repository under this org, named after the package. Each repo uses a **flat layout** — all files at the root, no subdirectories:

```
{package}/
  {package}.spec          ← spec file at root
  {package}-{ver}.tar.gz  ← committed source(s) when not fetchable upstream
  *.patch                 ← patches, if any
  sources                 ← lookaside hash file, if used
```

No `SPEC/`, `SOURCES/`, `Makefile`, `IDEA.md`, `CLAUDE.md`, `.github/`, or any other wrapper infrastructure. `spectool -g -R` fetches all `SourceN:` URLs at build time.

The `.github` repo (this one) contains only the shared build container and org profile.

---

## Published Repo Layout

Packages are published on SourceForge under `rpm-devel.sourceforge.io/repo/`:

```
RHEL/{VER}/{ARCH}/
  rpms/     CasjaysDev custom-built packages
  addons/   Upstream third-party mirrors (OS, langs, databases, infra)
  extras/   Community extras (EPEL, RPM Fusion, Ghettoforge, ELRepo)
  debug/    All debuginfo / debugsource RPMs

RHEL/{VER}/
  srpms/    Source RPMs (shared across arches — stored once per version)

Fedora/{VER}/{ARCH}/
  rpms/
  addons/
  extras/
  debug/

Fedora/{VER}/
  srpms/
```

### DNF Repo Sections

Clients receive a mirrorlist that resolves to SourceForge and its mirrors.

| Section | mirrorlist path | Contents |
|---|---|---|
| `casjay-rpms` | `ZREPO/RHEL/$releasever/$basearch/mirrors/rpms` | CasjaysDev-built packages |
| `casjay-addons` | `ZREPO/RHEL/$releasever/$basearch/mirrors/addons` | Upstream third-party (OS, langs, DBs, infra) |
| `casjay-extras` | `ZREPO/RHEL/$releasever/$basearch/mirrors/extras` | EPEL, RPM Fusion, Ghettoforge, ELRepo |
| `casjay-debug` | `ZREPO/RHEL/$releasever/$basearch/mirrors/debug` | debuginfo / debugsource |
| `casjay-sources` | `ZREPO/RHEL/$releasever/mirrors/srpms` | Source RPMs |

Install the `casjay-release` package to get all repo files and the GPG key:

```sh
dnf install -y https://github.com/rpm-devel/casjay-release/releases/latest/download/casjay-release.noarch.rpm
```

Or add the `casjay-rpms` section manually:

```ini
[casjay-rpms]
name=Casjay RPMs - $releasever $basearch
mirrorlist=https://github.com/rpm-devel/casjay-release/raw/main/ZREPO/RHEL/$releasever/$basearch/mirrors/rpms
gpgkey=https://github.com/rpm-devel/casjay-release/raw/main/ZREPO/RHEL/keys/RPM-GPG-KEY-casjay
enabled=1
module_hotfixes=1
```

---

## Build Container

All RPM builds run inside a single container — no host tools required.

```sh
docker pull ghcr.io/rpm-devel/build:latest
```

The image ships a complete RPM build environment:

| Category | Included |
|---|---|
| 🔧 RPM tools | `mock`, `rpm-build`, `rpm-sign`, `rpmdevtools`, `rpmlint`, `dnf-utils`, `createrepo_c` |
| 🏗️ Build toolchain | `gcc`, `gcc-c++`, `cmake`, `autoconf`, `automake`, `libtool`, `make`, `patch` |
| 📦 Common headers | `glibc-devel`, `openssl-devel`, `zlib-devel` |
| 🗜️ Archive formats | `bzip2`, `xz`, `zstd`, `unzip` |
| 🐍 Runtimes | `python3`, `perl` |
| 🔀 VCS | `git`, `git-lfs` |
| 🌐 Provider CLIs | `gh` (GitHub), `glab` (GitLab), `tea` (Gitea + Forgejo) |
| 🚀 CI/CD | `copr-cli`, `jq`, `curl`, `rsync` |
| 🔑 GPG | `gnupg2`, `pinentry` |

**Enabled repos:** Fedora main · RPM Fusion free + nonfree · GitHub CLI

> **Note:** `mock` requires `--privileged` to create its per-target chroot environments.

---

## Usage

### Interactive

```sh
docker run --rm -it --privileged \
  --name rpmbuild-$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
  -v "$HOME/rpmbuild:/root/rpmbuild" \
  -v "$HOME/Documents/builds:/root/Documents/builds" \
  -v "$HOME/.rpmmacros:/root/.rpmmacros:ro" \
  -v "$HOME/.gnupg:/root/.gnupg:ro" \
  ghcr.io/rpm-devel/build:latest
```

Inside the container — build a SRPM, then rebuild for each target with `mock`:

```sh
# Download sources and build SRPM
spectool -g -R ~/rpmbuild/SPECS/package.spec
rpmbuild -bs ~/rpmbuild/SPECS/package.spec

# Rebuild for every target (mock installs BuildRequires automatically)
mock -r almalinux-9-x86_64    --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r almalinux-9-aarch64   --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r almalinux-8-x86_64    --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r eol/centos-7-x86_64   --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r fedora-42-x86_64      --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r eol/fedora-41-x86_64  --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
```

For direct `rpmbuild -ba` (without mock):

```sh
dnf builddep -y ~/rpmbuild/SPECS/package.spec
rpmbuild -ba ~/rpmbuild/SPECS/package.spec
```

### Non-interactive (CI / scripted)

Set `RPM_TARGET` and pass either a `.spec` or `.src.rpm` as the command.

**From a `.spec` file** — entrypoint runs `spectool`, `rpmbuild -bs`, then `mock --rebuild` automatically:

```sh
docker run --rm -it --privileged \
  --name rpmbuild-$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
  -v "$HOME/rpmbuild:/root/rpmbuild" \
  -v "$HOME/Documents/builds:/root/Documents/builds" \
  -v "$HOME/.rpmmacros:/root/.rpmmacros:ro" \
  -v "$HOME/.gnupg:/root/.gnupg:ro" \
  -e RPM_TARGET=almalinux-9-x86_64 \
  -e RPM_GPG_KEY_ID="CasjaysDev RPM Dev <rpm-devel@casjaysdev.pro>" \
  ghcr.io/rpm-devel/build:latest \
  /root/rpmbuild/SPECS/package.spec
```

**From a pre-built `.src.rpm`** — passed directly to `mock --rebuild`:

```sh
docker run --rm -it --privileged \
  --name rpmbuild-$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
  -v "$HOME/rpmbuild:/root/rpmbuild" \
  -v "$HOME/Documents/builds:/root/Documents/builds" \
  -v "$HOME/.rpmmacros:/root/.rpmmacros:ro" \
  -v "$HOME/.gnupg:/root/.gnupg:ro" \
  -e RPM_TARGET=almalinux-9-x86_64 \
  ghcr.io/rpm-devel/build:latest \
  /root/rpmbuild/SRPMS/package-1.0-1.src.rpm
```

Built RPMs are copied to `$RPM_OUTPUT_DIR/$RPM_TARGET/` (default: `~/Documents/builds`).

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `RPM_TARGET` | *(unset)* | mock config name — when set, triggers non-interactive build |
| `RPM_OUTPUT_DIR` | `~/Documents/builds` | Directory to copy built RPMs into |
| `RPM_GPG_KEY_ID` | *(from `.rpmmacros`)* | Override the GPG key used for signing |
| `RPM_SIGN_PASS_FILE` | `~/.gnupg/rpm_sign_pass.txt` | Path to GPG passphrase file (must be mode `600`) |

---

## Supported Targets

Mock configs are provided by `mock-core-configs`. EOL targets use the `eol/` prefix.
All failures are hard errors — EOL targets are still in production and fully supported.

| Target | Mock config |
|---|---|
| RHEL / CentOS 7 (EOL) | `eol/centos-7-x86_64` · `eol/centos-7-aarch64` |
| RHEL / AlmaLinux 8 | `almalinux-8-x86_64` · `almalinux-8-aarch64` |
| RHEL / AlmaLinux 9 | `almalinux-9-x86_64` · `almalinux-9-aarch64` |
| RHEL / AlmaLinux 10 | `almalinux-10-x86_64` · `almalinux-10-aarch64` |
| Fedora 36–41 (EOL) | `eol/fedora-{36..41}-x86_64` · `eol/fedora-{36..41}-aarch64` |
| Fedora 42–current | `fedora-{N}-x86_64` · `fedora-{N}-aarch64` |
| Fedora Rawhide | `fedora-rawhide-x86_64` · `fedora-rawhide-aarch64` |

---

## Image Tags

| Tag | Contents |
|---|---|
| `:latest` | Most recent build — rebuilt on every push to `docker/**` and quarterly |
| `:YYMM` | Date-stamped snapshot (e.g. `:2604`) |
