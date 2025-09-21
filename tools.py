#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import time
import urllib.request
import json
import sys
import shlex
import datetime
import subprocess

def GetIpipInfo(para):
    try:
        with open("ip_json.json", 'r', encoding='utf-8') as f:
            ijson = json.load(f)
            if 'location' in ijson:
                jjson = ijson['location']
                if para in jjson:
                    print(jjson[para])
                else:
                    print(f"Error: Parameter '{para}' not found in location data")
            else:
                print("Error: Location data not found in JSON file")
    except FileNotFoundError:
        print("Error: ip_json.json file not found")
    except json.JSONDecodeError:
        print("Error: Invalid JSON format in ip_json.json")
    except Exception as e:
        print(f"Error reading IP information: {str(e)}")

def GetGeoioInfo(para):
    try:
        # Додаємо таймаут для запобігання зависання на повільних з'єднаннях
        with urllib.request.urlopen('http://ip-api.com/json', timeout=10) as ip_api:
            ijson = json.loads(ip_api.read().decode('utf-8'))
            if para in ijson:
                print(ijson[para])
            else:
                print(f"Error: Parameter '{para}' not found in API response")
    except Exception as e:
        print(f"Error getting geo information: {str(e)}")

def GetDiskInfo(para):
    try:
        temp = ExecShell("df -h -P|grep '/'|grep -v tmpfs")[0]
        if isinstance(temp, bytes):
            temp = temp.decode('utf-8')
        temp1 = temp.split('\n')
        diskInfo = []
        n = 0
        cuts = ['/mnt/cdrom', '/boot', '/boot/efi', '/dev', '/dev/shm', '/run/lock', '/run', '/run/shm', '/run/user']
        for tmp in temp1:
            if not tmp.strip():
                continue
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
            diskInfo = [disk[1], disk[2], disk[3], disk[4], disk[5]]
            break  # Беремо перший підходящий диск

        if not diskInfo:
            print("Error: No suitable disk found")
            return
            
        print(diskInfo[int(para)])
    except Exception as e:
        print(f"Error getting disk info: {str(e)}")

def ExecShell(cmdstring, cwd=None, timeout=None, shell=True):
    try:
        if shell:
            cmdstring_list = cmdstring
        else:
            cmdstring_list = shlex.split(cmdstring)
        
        # Перевірка наявності команди grep (для ARM64 та інших систем)
        if 'grep' in cmdstring and shell:
            # Перевірка наявності GNU grep
            check_grep = subprocess.run("which grep", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if check_grep.returncode != 0:
                # Спробувати використати альтернативний підхід
                if "df -h" in cmdstring:
                    # Для команди df використовуємо Python для фільтрації
                    df_cmd = "df -h -P"
                    df_proc = subprocess.Popen(df_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    stdout, stderr = df_proc.communicate()
                    if isinstance(stdout, bytes):
                        stdout = stdout.decode('utf-8')
                    # Фільтруємо результати вручну
                    filtered_lines = []
                    for line in stdout.split('\n'):
                        if '/' in line and 'tmpfs' not in line:
                            filtered_lines.append(line)
                    return ('\n'.join(filtered_lines), stderr)
        
        if timeout:
            end_time = datetime.datetime.now() + datetime.timedelta(seconds=timeout)

        sub = subprocess.Popen(cmdstring_list, cwd=cwd, stdin=subprocess.PIPE, shell=shell, bufsize=4096,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        while sub.poll() is None:
            time.sleep(0.1)
            if timeout:
                if end_time <= datetime.datetime.now():
                    sub.kill()
                    raise Exception(f"Timeout: {cmdstring}")

        return sub.communicate()
    except Exception as e:
        return (f"Error: {str(e)}", "")

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
