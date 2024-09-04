#!/bin/bash

# generate machine-id
test -f /etc/machine-id || uuidgen > /etc/machine-id

# set user envs
grep LANG /etc/profile &>/dev/null || echo "export LANG=${LANG:-en_US.UTF-8}" >> /etc/profile
grep LANGUAGE /etc/profile &>/dev/null || echo "export LANGUAGE=${LANG:-en_US.UTF-8}" >> /etc/profile
grep QT_XKB_CONFIG_ROOT /etc/profile &>/dev/null || echo "export QT_XKB_CONFIG_ROOT=/usr/share/X11/locale" >> /etc/profile
grep umask /etc/profile &>/dev/null || echo "umask ${DEFAULT_UMASK:-027}" >> /etc/profile
grep ${DEFAULT_USER_GROUP:-common} /etc/group &>/dev/null || groupadd -r ${DEFAULT_USER_GROUP:-common}
sed -i "/^SHELL/s#/bin/sh\$#${DEFAULT_USER_SHELL:-/bin/zsh}#" /etc/default/useradd

if [ "${SUDO_NOPASSWD}" = "true" ]
then
    sed -i '/^%sudo/s/.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    echo "%${DEFAULT_USER_GROUP:-common} ALL=(ALL) NOPASSWD: ${SUDO_DEFAULT_CMD:-/bin/whoami}" > /etc/sudoers.d/custom
else
    echo "%${DEFAULT_USER_GROUP:-common} ALL=(ALL) ${SUDO_DEFAULT_CMD:-/bin/whoami}" > /etc/sudoers.d/custom
fi

# add the ssh config if needed
test -f "/etc/ssh/sshd_config" || cp /etc/ssh_orig/sshd_config /etc/ssh
test -f "/etc/ssh/ssh_config" || cp /etc/ssh_orig/ssh_config /etc/ssh
test -f "/etc/ssh/moduli" || cp /etc/ssh_orig/moduli /etc/ssh
stat /etc/ssh/ssh_host_* &>/dev/null || ssh-keygen -A
install -d /var/run/sshd

# set default ssh public key
install -d -m 700 /etc/skel/.ssh
install -m 600 /dev/null /etc/skel/.ssh/authorized_keys
test -f /etc/ssh_orig/authorized_keys && cat /etc/ssh_orig/authorized_keys > /etc/skel/.ssh/authorized_keys

# set default user password
test $DEFAULT_USER_PASSWORD && echo "$DEFAULT_USER_PASSWORD" > /etc/users.pass
test -f /etc/users.pass && chmod 400 /etc/users.pass

# add or restore users
/usr/bin/create-users.sh

# generate xrdp key
test -f "/etc/xrdp/rsakeys.ini" || xrdp-keygen xrdp auto

# generate certificate for tls connection
if [ ! -f "/etc/xrdp/cert.pem" ];
then
    # delete eventual leftover private key
    rm -f /etc/xrdp/key.pem || true
    cd /etc/xrdp
    if [ ! $CERTIFICATE_SUBJECT ]; then
        CERTIFICATE_SUBJECT="/C=US/ST=Some State/L=Some City/O=Some Org/OU=Some Unit/CN=Terminalserver"
    fi
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 3650 -subj "$CERTIFICATE_SUBJECT"
    crudini --set /etc/xrdp/xrdp.ini Globals security_layer tls
    crudini --set /etc/xrdp/xrdp.ini Globals certificate /etc/xrdp/cert.pem
    crudini --set /etc/xrdp/xrdp.ini Globals key_file /etc/xrdp/key.pem
fi

# feature toggle: when a xrdp user disconnected, kill all their processes
test "$AUTO_KILL_INACTIVE_USER" = "true" && crudini --set /etc/supervisor/conf.d/auto-kill-inactive-user.conf program:auto-kill-inactive-user autostart true

# feature toggle: auto create user when a invalid ssh user attempt to login
test "$AUTO_CREATE_SSH_USER" = "true" && crudini --set /etc/supervisor/conf.d/auto-create-user.conf program:auto-create-user autostart true

# feature toggle: prohibit root user login
test "$XRDP_ALLOW_ROOT_LOGIN" = "false" && crudini --set /etc/xrdp/sesman.ini Security AllowRootLogin false

# update apt source 
test -n "$APT_MIRROR_URL" && sed -i "s|http[s]*://[^ ]*|$APT_MIRROR_URL|g" /etc/apt/sources.list

exec "$@"
