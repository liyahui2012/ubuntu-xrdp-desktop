#!/bin/bash

# 先对 /home 目录下已存在的用户家目录进行恢复（用户组、密码默认设置）
for username in $(ls /home)
do
    id $username &>/dev/null || adddyuser $username
done

# 再按 /etc/users.list 内容创建用户或修改用户密码、用户组
sed '/^#/d; /^$/d' /etc/users.list | while read username hashed_password groups
do
    id $username &>/dev/null || adddyuser $username
    echo $username:$hashed_password | chpasswd -e
    test $groups && usermod -G ${groups} $username
done
