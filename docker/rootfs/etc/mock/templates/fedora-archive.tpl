# fedora-archive.tpl — mock config template for EOL Fedora releases
# Uses archives.fedoraproject.org instead of mirrors.fedoraproject.org/metalink,
# which stops serving EOL releases once a version goes end-of-life.
# Included by eol/fedora-{36..41}-{x86_64,aarch64}.cfg configs.
config_opts['root'] = 'fedora-{{ releasever }}-{{ target_arch }}'
config_opts['description'] = 'Fedora {{ releasever }} (EOL — archives.fedoraproject.org)'
config_opts['chroot_setup_cmd'] = 'install @buildsys-build'

config_opts['dist'] = 'fc{{ releasever }}'
config_opts['extra_chroot_dirs'] = ['/run/lock']
config_opts['package_manager'] = '{% if releasever|int >= 40 %}dnf5{% else %}dnf{% endif %}'

# Use quay.io for bootstrap — registry.fedoraproject.org drops old tags faster
config_opts['bootstrap_image'] = 'quay.io/fedora/fedora:{{ releasever }}'
# bootstrap_image_ready means mock can use the image as a complete chroot directly;
# false for EOL versions — let mock install the build group from repos instead
config_opts['bootstrap_image_ready'] = False

config_opts['dnf.conf'] = """
[main]
keepcache=1
debuglevel=2
reposdir=/dev/null
logfile=/var/log/yum.log
retries=20
obsoletes=1
gpgcheck=0
assumeyes=1
syslog_ident=mock
syslog_device=
install_weak_deps=0
metadata_expire=0
best=1
module_platform_id=platform:f{{ releasever }}
protected_packages=
user_agent={{ user_agent }}

[fedora]
name=Fedora {{ releasever }} Archive - $basearch
baseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/{{ releasever }}/Everything/$basearch/os/
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/fedora/RPM-GPG-KEY-fedora-{{ releasever }}-primary
skip_if_unavailable=False

[updates]
name=Fedora {{ releasever }} Updates Archive - $basearch
baseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/updates/{{ releasever }}/Everything/$basearch/
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/fedora/RPM-GPG-KEY-fedora-{{ releasever }}-primary
skip_if_unavailable=False

[fedora-source]
name=Fedora {{ releasever }} Archive - Source
baseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/{{ releasever }}/Everything/source/tree/
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/fedora/RPM-GPG-KEY-fedora-{{ releasever }}-primary
enabled=0
skip_if_unavailable=False

[updates-source]
name=Fedora {{ releasever }} Updates Archive - Source
baseurl=https://archives.fedoraproject.org/pub/archive/fedora/linux/updates/{{ releasever }}/Everything/SRPMS/
gpgcheck=1
gpgkey=file:///usr/share/distribution-gpg-keys/fedora/RPM-GPG-KEY-fedora-{{ releasever }}-primary
enabled=0
skip_if_unavailable=False
"""
