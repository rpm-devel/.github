# rpm-devel

RPM packaging organization for [CasjaysDev](https://github.com/casjaysdev). Builds signed RPM packages for RHEL/AlmaLinux (EL7–EL10) and Fedora (36+), distributed via a self-hosted DNF repository.

## Build Container

All RPM builds run inside a single container that ships `mock`, `rpmbuild`, `rpmsign`, and `createrepo_c` — no host tools required.

```sh
docker pull ghcr.io/rpm-devel/build:latest
```

### Usage

> **Note:** `mock` requires `--privileged` to create its per-target chroot environments.

```sh
docker run --rm -it --privileged \
  --name rpmbuild-$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
  --platform linux/amd64 \
  -v "$HOME/rpmbuild:/root/rpmbuild" \
  -v "$HOME/Documents/builds:/root/Documents/builds" \
  -v "$HOME/.rpmmacros:/root/.rpmmacros:ro" \
  -v "$HOME/.gnupg:/root/.gnupg:ro" \
  ghcr.io/rpm-devel/build:latest
```

### Supported Targets

| Target | Mock config |
|---|---|
| RHEL / CentOS 7 | `centos-7-x86_64` · `centos-7-aarch64` |
| RHEL / AlmaLinux 8 | `almalinux-8-x86_64` · `almalinux-8-aarch64` |
| RHEL / AlmaLinux 9 | `almalinux-9-x86_64` · `almalinux-9-aarch64` |
| RHEL / AlmaLinux 10 | `almalinux-10-x86_64` · `almalinux-10-aarch64` |
| Fedora 36 → current | `fedora-36-x86_64` … `fedora-latest-x86_64` |

Build for a specific target:

```sh
# Build a SRPM first, then rebuild for each target
rpmbuild -bs ~/rpmbuild/SPECS/package.spec

mock -r almalinux-9-x86_64  --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r almalinux-9-aarch64 --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
mock -r centos-7-x86_64     --rebuild ~/rpmbuild/SRPMS/package-1.0-1.src.rpm
```

### Image tags

| Tag | Contents |
|---|---|
| `:latest` | Most recent build — rebuilt on every push to `main` and quarterly |
| `:YYMM` | Date-stamped snapshot (e.g. `:2604`) |

## Repository Layout

Each package lives in its own repo under this org, named after the package. The `.github` repo contains only the shared build container and org profile.

## DNF Repository

Packages are published at `https://sourceforge.net/projects/casjaysdev/files/RHEL/`.

```ini
[casjaysdev]
name=CasjaysDev - $releasever - $basearch
baseurl=https://sourceforge.net/projects/casjaysdev/files/RHEL/el$releasever/$basearch/casjay/
gpgcheck=1
gpgkey=https://github.com/rpm-devel.gpg
enabled=1
```
