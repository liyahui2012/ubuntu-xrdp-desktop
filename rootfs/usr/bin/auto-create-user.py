#!/usr/bin/env python3

import subprocess
import os,sys
import re
import time
import logging

logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.INFO)

SSHD_LOG_FILE = "/var/log/sshd.log"
CREATE_USER_CMD = "/usr/bin/adddyuser"

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

def main():
    invalid_user_pattern = re.compile(r'Invalid user (.*) from ([0-9.:]+) .*')
    trusted_ips = set(os.getenv("SSH_TRUSTED_IPS", "127.0.0.1 ::1").split())

    for line in tail_f(SSHD_LOG_FILE):
        match = invalid_user_pattern.match(line)
        if match:
            username, ip = match.groups()
            logging.info(f"Invalid ssh user login: {username}@{ip}")
            if ip in trusted_ips:
                try:
                    subprocess.run([CREATE_USER_CMD, username], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    logging.info(f"User {username} created successfully")
                except subprocess.CalledProcessError as e:
                    logging.error(f"Failed to create user {username}: {e}")
            else:
                logging.warning(f"IP {ip} is not trusted, nothing to do")

if __name__ == "__main__":
    main()
