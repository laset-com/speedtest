#!/usr/bin/env python
# -*- coding: UTF-8 -*-

import time
import urllib.request
import json
import sys
import shlex
import datetime
import subprocess

def GetIpipInfo(para):
    with open("ip_json.json", 'r') as f:
        ijson = json.load(f)
        jjson = ijson['location']
        print(jjson[para])

def GetGeoioInfo(para):
    with urllib.request.urlopen('http://ip-api.com/json') as ip_api:
        ijson = json.loads(ip_api.read().decode('utf-8'))
        print(ijson[para])

def GetDiskInfo(para):
    temp = ExecShell("df -h -P|grep '/'|grep -v tmpfs")[0]
    temp1 = temp.split('\n')
    diskInfo = []
    n = 0
    cuts = ['/mnt/cdrom', '/boot', '/boot/efi', '/dev', '/dev/shm', '/run/lock', '/run', '/run/shm', '/run/user']
    for tmp in temp1:
        n += 1
        disk = tmp.split()
        if len(disk) < 5:
            continue
        if 'M' in disk[1]:
            continue
        if 'K' in disk[1]:
            continue
        if len(disk[5].split('/')) > 4:
            continue
        if disk[5] in cuts:
            continue
        arr = {}
        diskInfo = [disk[1], disk[2], disk[3], disk[4], disk[5]

    print(diskInfo[int(para)])

def ExecShell(cmdstring, cwd=None, timeout=None, shell=True):
    if shell:
        cmdstring_list = cmdstring
    else:
        cmdstring_list = shlex.split(cmdstring)
    if timeout:
        end_time = datetime.datetime.now() + datetime.timedelta(seconds=timeout)

    sub = subprocess.Popen(cmdstring_list, cwd=cwd, stdin=subprocess.PIPE, shell=shell, bufsize=4096,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    while sub.poll() is None:
        time.sleep(0.1)
        if timeout:
            if end_time <= datetime.datetime.now():
                raise Exception("Timeout：%s" % cmdstring)

    return sub.communicate()

if __name__ == "__main__":
    _type = sys.argv[1]
    if _type == 'disk':
        GetDiskInfo(sys.argv[2])
    elif _type == 'geoip':
        GetGeoioInfo(sys.argv[2])
    elif _type == 'ipip':
        GetIpipInfo(sys.argv[2])
    else:
        print('ERROR: Parameter error')
