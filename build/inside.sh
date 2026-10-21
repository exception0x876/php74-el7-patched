#!/usr/bin/env bash
# Runs inside a clean centos:7 container (called by build.sh). Do not run on a real host.
set -euxo pipefail

# --- repositories: CentOS 7 and EPEL 7 are EOL, point them at archives ------------------
# vault.centos.org returns 403 for the *.sqlite.bz2 metadata yum 3 prefers, so use the
# kernel.org mirror of the 7.9.2009 vault.
sed -i 's#^mirrorlist=#\#mirrorlist=#' /etc/yum.repos.d/CentOS-*.repo
sed -i 's#^\#\?baseurl=http://mirror.centos.org/centos/\$releasever/#baseurl=https://archive.kernel.org/centos-vault/7.9.2009/#' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's#^baseurl=http://vault.centos.org/centos/\$releasever/#baseurl=https://archive.kernel.org/centos-vault/7.9.2009/#' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's#^baseurl=http://vault.centos.org/centos/\$releasever/\([a-z]*\)/Source/#baseurl=https://archive.kernel.org/centos-vault/7.9.2009/\1/Source/#' /etc/yum.repos.d/CentOS-Sources.repo
sed -i 's#^\#\?baseurl=http://mirror.centos.org/centos/\$releasever/\([a-z]*\)/Source/#baseurl=https://archive.kernel.org/centos-vault/7.9.2009/\1/Source/#' /etc/yum.repos.d/CentOS-Sources.repo
yum clean all
yum -y install epel-release yum-utils
cat > /etc/yum.repos.d/epel.repo <<'EOF'
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch (archive)
baseurl=https://archives.fedoraproject.org/pub/archive/epel/7/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
EOF
rm -f /etc/yum.repos.d/epel-testing.repo
yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
# gd3php-devel and oniguruma5php-devel live in [remi]; remi-php74/remi-safe as in the reference build
yum-config-manager --enable remi remi-php74 remi-safe >/dev/null

# --- build tools and user -------------------------------------------------------------
yum -y install rpm-build redhat-rpm-config rpmdevtools
useradd -m builder
install -d -o builder -g builder /home/builder/rpmbuild/{SPECS,SOURCES,BUILD,RPMS,SRPMS}
cp /srpm/php74.spec /home/builder/rpmbuild/SPECS/
find /srpm -maxdepth 1 -type f ! -name php74.spec -exec cp {} /home/builder/rpmbuild/SOURCES/ \;
chown -R builder: /home/builder/rpmbuild

# --- build dependencies (the spec has BuildRequires: icu >= 73 after patch 0001) --------
yum-builddep -y /home/builder/rpmbuild/SPECS/php74.spec

# --- build: binary RPMs (runs the PHP test suite), then the SRPM -----------------------
su builder -c 'cd /home/builder/rpmbuild && rpmbuild -bb SPECS/php74.spec' 2>&1 | tee /out/build.log
su builder -c 'cd /home/builder/rpmbuild && rpmbuild -bs SPECS/php74.spec'

cp /home/builder/rpmbuild/RPMS/*/*.rpm /home/builder/rpmbuild/SRPMS/*.rpm /out/
