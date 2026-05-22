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

RUN dnf install -y \
      tini \
      mock \
      mock-core-configs \
      rpm-build \
      rpm-sign \
      rpmdevtools \
      createrepo_c \
      gnupg2 \
      git \
      make \
      gcc \
      wget \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/log/dnf* /var/log/hawkey.log

# Add root to mock group so mock works without sudo inside the container
RUN usermod -aG mock root

# CentOS 7 is EOL — official mirrors are dead; override to vault.centos.org
COPY rootfs/etc/mock/centos-7-x86_64.cfg   /etc/mock/centos-7-x86_64.cfg
COPY rootfs/etc/mock/centos-7-aarch64.cfg  /etc/mock/centos-7-aarch64.cfg

# Entrypoint: configures signing env vars and optionally runs a non-interactive build
COPY rootfs/usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# Pre-create the standard rpmbuild tree
RUN rpmdev-setuptree

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
