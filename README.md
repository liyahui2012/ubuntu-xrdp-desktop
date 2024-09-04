# 说明

本项目基于 https://github.com/danielguerra69/ubuntu-xrdp 创建，目标使用场景是用于服务器环境下替代 Windows 服务器作为维护操作终端（支持多用户登录），本项目主要改造内容如下：

+ 中文环境与输入法支持（默认使用右Ctrl键切换输入法）

+ 预装更多常用软件

  + zsh tmux telnet ping lszrz git 等常用维护命令
  + kubectl helm k9s stern mc ansible redis-cli mongosh mysql-client-5.7 kafkacat postgres-client-13 等命令行工具
  + nodejs openjdk golang python 等语言运行环境
  + firefox chrome 浏览器
  + Postman vscode offsetexplore studio-3t dbeaver-ce 图形软件

+ 增加两个系统管理脚本

  + `/usr/bin/auto-create-user.py` 自动创建不存在的用户（高风险）
  + `/usr/bin/auto-kill-inactive-user.py` 自动杀死已断开 RDP 连接的用户的所有进程（可设置延迟时间）
  
+ 支持 ubuntu:20.04/22.04 两个基础镜像

+ 移除自动锁屏相关配置与软件包

+ 禁用 supervisorctl 普通用户操作权限

+ 其他修改请查看源码

# 镜像标签

命名方式：[版本]-[操作系统版本]-[base|essentials|utils]

```
v1-22.04-base: 包含基本图形环境、中文支持与用户管理脚本
v1-22.04-essentials: 包含浏览器和一些基础的命令行工具
v1-22.04-utils: 包含更多个人所需的软件和命令行工具
```

# 部署运行

```bash
docker run -d --name ubuntu-xrdp-desktop --shm-size 1g -p 3389:3389 -p 2222:22 alvinleee/ubuntu-xrdp-desktop:v1-22.04-utils
```

`--shm-size 1g` 是浏览器需要的参数，不然使用的时候会崩溃

其他参数请见配置说明与 docker-compose.yaml 示例

# 环境变量

+ LANG: zh_CN.UTF-8

  全局语言配置，决定图形界面显示语言，默认值：en_US.UTF-8

+ DEFAULT_UMASK: "027"

  全局 umask 配置，默认值：027

+ DEFAULT_USER_SHELL: /bin/zsh

  用户 SHELL 环境配置，默认值：/bin/zsh

+ DEFAULT_USER_GROUP: common

  使用 /usr/bin/adddyuser 创建用户时指定的附加用户组（不允许多个组），默认值：common(999)

+ DEFAULT_USER_PASSWORD: "$$6$$Fue.F9HIwYE7Le3j$$RskBpnzz5Pgy55NNHqenHhBFaDhpDh9uOP/ChVGm7jgw4NT2d4DRV0xseakidTv27UtjWaNSMEnUs0NQ.OUYF/"

  使用 /usr/bin/adddyuser 创建用户时指定的默认密码（ChangeMe），该密码字符串由 `openssl passwd -6 ChangeMe` 命令生成（生成后的密码需要将 $ 替换为 $$），若该变量或 /etc/users.pass 文件不存在则设置随机密码（默认）

+ SUDO_NOPASSWD: true

  使用 sudo 是否可以免密，默认值：false

+ SUDO_DEFAULT_CMD: /bin/whoami

  普通用户使用 sudo 能执行的命令，默认值：/bin/whoami

+ AUTO_CREATE_SSH_USER: true

  使用不存在的账号 ssh 登录时会自动创建相应账号（需登录失败一次后才会创建），默认值：false

+ SSH_TRUSTED_IPS: 127.0.0.1 ::1

  只有从该变量指定的 IP 地址 ssh 登录才会触发自动创建账号的动作，配置格式：IP1 IP2 IP3，默认值：127.0.0.1 ::1

+ AUTO_KILL_INACTIVE_USER: true

  自动杀死断开 RDP 连接的用户进程，默认值：false

+ XRDP_DISC_TIME_LIMIT: 5

  断开 RDP 连接的用户超时等待时间（配合 AUTO_KILL_INACTIVE_USER 使用），默认值：5，单位：分钟

+ XRDP_ALLOW_ROOT_LOGIN: false

  禁止 root 账号从 RDP 登录，默认值：true

+ APT_MIRROR_URL: https://mirrors.ustc.edu.cn/ubuntu/

  启动时替换 /etc/apt/sources.list 中的仓库地址，默认值：无

# 挂载卷

+ /etc/ssh/

+ /home/

+ /etc/ssh_orig/authorized_keys

  全局用户 ssh 公钥（用于堡垒机或超管使用同一个私钥进行登录），注意实际应用中不要使用本仓库中 test 目录下的测试公钥

+ /etc/users.pass

  /usr/bin/adddyuser 命令创建用户时使用的默认密码读取文件（DEFAULT_USER_PASSWORD 变量内容将写入该文件），用户也可以直接挂载包含密码信息的文件来代替 DEFAULT_USER_PASSWORD 变量配置的方式

+ /etc/users.list

  系统启动时自动创建的用户清单，内容格式如下：

  ```
  # 用户名 加密密码 用户组（可选、可多个用户组）
  user1 $6$Fue.F9HIwYE7Le3j$RskBpnzz5Pgy55NNHqenHhBFaDhpDh9uOP/ChVGm7jgw4NT2d4DRV0xseakidTv27UtjWaNSMEnUs0NQ.OUYF/ sudo
  user2 $6$Fue.F9HIwYE7Le3j$RskBpnzz5Pgy55NNHqenHhBFaDhpDh9uOP/ChVGm7jgw4NT2d4DRV0xseakidTv27UtjWaNSMEnUs0NQ.OUYF/ sudo,common
  ```
  
  在实际的容器启动过程中，以下问题需要注意：
  
  + 注释行和已存在用户将被忽略

  + 用户组为附加组（可以不设置或者指定多个组）

# 用户管理

+ /usr/bin/adddyuser

  创建用户的简化命令，只接受用户名、附加用户组（默认创建用户同名组）作为参数，密码使用全局默认设置或者随机密码。
  
+ /usr/bin/create-users.sh

  用于容器创建或重建时的初始用户（/etc/users.list）创建和用户账号恢复