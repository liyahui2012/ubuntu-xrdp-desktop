#!/usr/bin/env python3

import subprocess,threading
import time,re
import os
import logging

logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.INFO)

XRDP_SESMAN_LOG_FILE = "/var/log/xrdp-sesman.log"

def command(cmd):
    cmd = cmd.strip().split() if isinstance(cmd, str) else cmd
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def tail_f(filename, st=1):
    with open(filename, "r") as f:
        f.seek(0, 2)
        while True:
            line = f.readline()
            if not line:
                if os.fstat(f.fileno()).st_size < f.tell():
                    f.seek(0, 2)
                time.sleep(st)
                continue
            yield line

def get_active_users():
    users = set(command('ps -eo user --no-headers').stdout.split())
    users.remove('root')
    return users

def get_active_sockets():
    sockets = command('ss -tH sport :3389').stdout.split()
    remote_ips = [re.sub(r'[\[\]]', '', x.split()[-1]) for x in sockets]
    return remote_ips

def track_xrdp_events():
    connect_event_pattern = re.compile(r'.*\+\+ (\w+) session.* username (\w+),.* ip ([^\s]+)')

    for line in tail_f(XRDP_SESMAN_LOG_FILE):
        match = connect_event_pattern.match(line)
        if match:
            action, username, ip = match.groups()
            if action in ['created', 'reconnected']:
                active_users.update({username: ip})
                logging.info(f"user {username} has connected")

def kill_offline_user():
    ideltime = os.getenv('XRDP_DISC_TIME_LIMIT', '5')
    ideltime = int(ideltime) if ideltime.isdigit() else 5

    while True:
        active_ips = get_active_sockets()
        for username, flag in active_users.copy().items():
            if isinstance(flag, str):
                ip = flag
                if ip not in active_ips:
                    active_users[username] = 0
                    logging.info(f"{username}'s session disconnected，set a count flag")
            elif isinstance(flag, int):
                count = flag + 1
                active_users[username] = count
                logging.info(f"{username} has disconnected for {count} minite")
                if count >= ideltime:
                    command(f'pkill -u {username}')
                    active_users.pop(username)
                    logging.info(f"kill all processes of {username}")
        time.sleep(60)

def main():
    global active_users
    active_users = {}

    threads = []
    threads.append(threading.Thread(target=track_xrdp_events))
    threads.append(threading.Thread(target=kill_offline_user))

    for t in threads: t.start()
    for t in threads: t.join()

if __name__ == "__main__":
    main()
