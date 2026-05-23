# syntax=docker/dockerfile:1
FROM fedora:latest

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Static labels
LABEL org.opencontainers.image.title="rpm-devel build" \
      org.opencontainers.image.description="RPM build environment — mock, rpmbuild, rpmsign, createrepo_c for all EL and Fedora targets" \
      org.opencontainers.image.url="https://github.com/rpm-devel/.github" \
      org.opencontainers.image.source="https://github.com/rpm-devel/.github" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="CasjaysDev"

# Dynamic labels (injected at build time)
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}"

# RPM build toolchain — mock, rpmbuild, signing, repo management,
# common build deps, CI/CD integrations (copr-cli, jq), and source tools.
# Covers interactive use, direct rpmbuild -ba, and mock-based chroot builds.
RUN dnf install -y \
      tini \
      \
      mock \
      mock-core-configs \
      \
      rpm-build \
      rpm-sign \
      rpmdevtools \
      rpmlint \
      dnf-utils \
      createrepo_c \
      \
      gcc \
      gcc-c++ \
      binutils \
      make \
      cmake \
      autoconf \
      automake \
      libtool \
      pkgconf-pkg-config \
      patch \
      diffutils \
      \
      glibc-devel \
      openssl-devel \
      zlib-devel \
      \
      bzip2 \
      xz \
      zstd \
      unzip \
      \
      python3 \
      python3-pip \
      perl \
      \
      git \
      git-lfs \
      \
      curl \
      wget \
      rsync \
      \
      copr-cli \
      jq \
      bc \
      file \
      which \
      hostname \
      \
      gnupg2 \
      pinentry \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/log/dnf* /var/log/hawkey.log

# Extra repos — RPM Fusion (free + nonfree) for Fedora, so dnf builddep
# can resolve packages not in the main Fedora repo (codecs, drivers, etc.).
# EPEL applies only to EL targets; mock handles it via its chroot configs.
RUN dnf install -y \
      https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/log/dnf* /var/log/hawkey.log

# Provider CLIs — gh (GitHub), glab (GitLab), tea (Gitea + Forgejo)
# gh: official RPM repo; glab + tea: latest release binary from their APIs
RUN set -euo pipefail; \
    case "$(uname -m)" in \
      x86_64)  GOARCH=amd64 ;; \
      aarch64) GOARCH=arm64 ;; \
      *)       echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -qLSs https://cli.github.com/packages/rpm/gh-cli.repo \
      -o /etc/yum.repos.d/gh-cli.repo; \
    dnf install -y gh; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/log/dnf* /var/log/hawkey.log; \
    GLAB_VER=$(curl -qLSs \
      "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases" \
      | jq -r '.[0].tag_name'); \
    curl -qLSs \
      "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_VER}/downloads/glab_${GLAB_VER#v}_linux_${GOARCH}.tar.gz" \
      | tar -xz -C /tmp; \
    install -m 0755 /tmp/bin/glab /usr/local/bin/glab; \
    rm -rf /tmp/bin; \
    TEA_URL=$(curl -qLSs \
      "https://gitea.com/api/v1/repos/gitea/tea/releases?limit=1" \
      | jq -r --arg a "linux-${GOARCH}" \
        '.[0].assets[] | select(.name | test("tea-[0-9.]+-" + $a + "$")) | .browser_download_url'); \
    curl -qLSs "$TEA_URL" -o /usr/local/bin/tea; \
    chmod 0755 /usr/local/bin/tea

# Add root to mock group so mock works without sudo inside the container
RUN usermod -aG mock root

# Override EOL Fedora configs (36-41) to use archives.fedoraproject.org.
# mock-core-configs ships these pointing at mirrors.fedoraproject.org/metalink,
# which stops serving content once a Fedora release goes EOL.
COPY rootfs/etc/mock/templates/fedora-archive.tpl /etc/mock/templates/fedora-archive.tpl
RUN for ver in 36 37 38 39 40 41; do \
      for arch in x86_64 aarch64; do \
        printf "config_opts['releasever'] = '%s'\nconfig_opts['target_arch'] = '%s'\nconfig_opts['legal_host_arches'] = ('%s',)\n\ninclude('templates/fedora-archive.tpl')\n" \
          "${ver}" "${arch}" "${arch}" \
          > "/etc/mock/eol/fedora-${ver}-${arch}.cfg"; \
      done; \
    done

# Entrypoint: configures signing env vars and optionally runs a non-interactive build
COPY rootfs/usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# Pre-create the standard rpmbuild tree
RUN rpmdev-setuptree

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
