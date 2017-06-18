#!/bin/sh

set -e

# First param is the tarball, 2nd is the checksum
VerifySha()
{
    test_sum=$(awk -v myvar="$1" '$2==myvar {for(i=1; i<=1; i++) { print $1; exit}}' $2)
    calculated_sum=$(sha1sum $1 | awk '{print $1}' -)
    if [[ "$test_sum" == "$calculated_sum" ]] ; then
        return 0
    else
        return 1
    fi
}

# Param is repository name
AddLocalSync()
{
    sed -e "/^sync/ s|$| local: git+file:///tmp/ciwork/$1|" -i /etc/paludis/repositories/$1.conf
}

baseurl="http://dev.exherbo.org/stages/"
rootfs="exherbo-amd64-current.tar.xz"
checksum="sha1sum"

# Create working directory, keep a copy of busybox
mkdir /work
cp /bin/busybox /work
mkdir /work/rootfs
cd /work/rootfs


echo "Downloading rootfs"
wget -c "${baseurl}/${rootfs}" "${baseurl}/${checksum}"
if VerifySha ${rootfs} ${checksum} ; then
    echo "Checksum is OK"
else
    echo "Checksum is NOT OK"
    return 1
fi

echo "Unpacking rootfs"
tar --exclude "./dev" --exclude "./proc" --exclude "./sys" --exclude "./etc/hosts" --exclude "./etc/hostname" --exclude "./etc/resolv.conf" -xf ${rootfs}
/work/busybox rm -f ${rootfs} ${checksum}

echo "Cleaning up"
cd /
/work/busybox rm -rf /bin /build.sh /etc /home /root /tmp /usr /var || true
/work/busybox mv /work/rootfs/etc/* /etc || true
/work/busybox rm -rf /work/rootfs/etc
/work/busybox mv /work/rootfs/* /
/work/busybox rm -rf /work

echo "Contents of rootfs:"
ls -lah

echo "Setting up CI environment"
source /etc/profile
eclectic env update

chgrp paludisbuild /dev/tty
export PALUDIS_DO_NOTHING_SANDBOXY=1

echo "sys-apps/paludis ruby" >> /etc/paludis/options.conf
AddLocalSync "arbor"

# disable tests
echo '*/* build_options: -recommended_tests' >> /etc/paludis/options.conf

cave sync
eclectic news read new
cave resolve world -cx
cave resolve ruby-elf -x
cave purge -x
cave fix-linkage -x
eclectic config accept-all

# reenable tests again
sed '/\*\/\* build_options: -recommended_tests/d' -i /etc/paludis/options.conf

echo "Downloading build scripts"
cd /usr/local/bin
wget -c https://git.exherbo.org/infra-scripts.git/plain/continuous-integration/gitlab/buildtest
wget -c https://git.exherbo.org/infra-scripts.git/plain/continuous-integration/gitlab/handle_confirmations
wget -c https://git.exherbo.org/infra-scripts.git/plain/continuous-integration/gitlab/commits_to_build.rb
wget -c https://git.exherbo.org/exherbo-dev-tools.git/plain/mscan2.rb
chmod +x buildtest handle_confirmations commits_to_build.rb mscan2.rb

echo "Cleaning up again"
rm -f /root/.bash_history
rm -Rf /tmp/*
rm -Rf /var/tmp/paludis/build/*
rm -Rf /var/cache/paludis/distfiles/*
rm -Rf /var/log/paludis/*
rm -f /var/log/paludis.log

