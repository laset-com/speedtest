# Website

https://bench.laset.com

# Speedtest Bench - Server/VPS Benchmark Script, System Info, I/O Test and Speedtest

Server/VPS Speedtest Script, system info, I/O test and speedtest

[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/laset-com/speedtest)

---

## About This Script

This script is a standard Bash script designed to run on most Linux distributions, including Debian, Ubuntu, CentOS, Fedora, Arch Linux, Rocky Linux, AlmaLinux, and their derivatives. It is compatible with x86_64, x86, ARM64, and ARM architectures.

The script provides a comprehensive system performance analysis, which includes:
*   Detailed information about the OS, kernel, CPU, RAM, SWAP, and disk space.
*   Geekbench CPU tests (v4, v5, v6, automatically selected based on RAM size).
*   I/O speed tests for CPU, RAM, and disk.
*   Speedtest.net network speed tests (global and regional).
*   Virtualization type and geographical location detection.

The script requires `bash` to run. It will automatically install necessary tools such as `curl` or `wget`, `python3`, `bzip2`, `tar`, and `smartmontools` (for extended disk information) if they are not already present. Running the script requires `root` privileges.

## Global Speedtest

Here are some common commands to run the benchmark:

*   **Run full benchmark**
    ```bash
    curl -sL bench.laset.com | bash
    ```
*   **Just Global Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -speed
    ```
*   **Benchmark & The US Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -us
    ```
*   **Just the US Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -uss
    ```
*   **Benchmark & Europe Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -eu
    ```
*   **Just Europe Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -eus
    ```
*   **Benchmark & Middle East Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -me
    ```
*   **Just Middle East Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -mes
    ```
*   **Benchmark & India Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -in
    ```
*   **Just India Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -ins
    ```
*   **Benchmark & Asia Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -asia
    ```
*   **Just Asia Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -as
    ```
*   **Benchmark & Australia & New Zealand Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -au
    ```
*   **Just Australia & New Zealand Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -aus
    ```
*   **Benchmark & South America Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -sa
    ```
*   **Just South America Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -sas
    ```
*   **Also, instead of curl, you can use wget**
    ```bash
    wget -qO- bench.laset.com | bash
    ```

## More Arguments

Here are the available arguments and example commands:

*   **System Information**
    ```bash
    curl -sL bench.laset.com | bash -s -- -info
    # or
    curl -sL bench.laset.com | bash -s -- -i
    ```
*   **I/O Test**
    ```bash
    curl -sL bench.laset.com | bash -s -- -io
    ```
*   **GeekBench CPU Test (auto-selects v4, v5, or v6)**
    ```bash
    curl -sL bench.laset.com | bash -s -- -gb
    ```
*   **GeekBench CPU v4 Test**
    ```bash
    curl -sL bench.laset.com | bash -s -- -gb4
    ```
*   **GeekBench CPU v5 Test**
    ```bash
    curl -sL bench.laset.com | bash -s -- -gb5
    ```
*   **GeekBench CPU v6 Test**
    ```bash
    curl -sL bench.laset.com | bash -s -- -gb6
    ```
*   **System info, I/O & Global Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -all
    ```
*   **Just India Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -ins
    # or
    curl -sL bench.laset.com | bash -s -- -inspeed
    ```
*   **System info, I/O & China Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -cn
    # or
    curl -sL bench.laset.com | bash -s -- -china
    ```
*   **Just China Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -cns
    # or
    curl -sL bench.laset.com | bash -s -- -cnspeed
    ```
*   **System info, I/O & Ukraine Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -ua
    # or
    curl -sL bench.laset.com | bash -s -- -ukraine
    ```
*   **Just Ukraine Speedtest**
    ```bash
    curl -sL bench.laset.com | bash -s -- -uas
    # or
    curl -sL bench.laset.com | bash -s -- -uaspeed
    ```
*   **IP info**
    ```bash
    curl -sL bench.laset.com | bash -s -- -ip
    ```
*   **Show about**
    ```bash
    curl -sL bench.laset.com | bash -s -- -a
    ```

## Compatibility

This script is engineered for broad compatibility across diverse Linux distributions and architectures, relying on standard `bash` and common system utilities. To run the script, you must have either `curl` or `wget` installed. The script includes built-in logic to automatically install other necessary dependencies (e.g., `python3`, `bzip2`, `tar`, `smartmontools`) to simplify deployment. For optimal operation, ensure `bash` is installed and the script is executed with `root` privileges. If you encounter any issues, please report them on the [GitHub Issues page](https://github.com/laset-com/speedtest/issues).

## Sample Output (Global)

```text
root@chicago:~# curl -sL bench.laset.com | bash
---------------------------------------------------------------------------
 Region: Global  https://bench.laset.com v1.8.2 2025-09-22 
 Usage : curl -sL bench.laset.com | bash -s -- -Global
---------------------------------------------------------------------------
 OS           : Debian GNU/Linux 12 (64 Bit)
 Virt/Kernel  : KVM / 6.1.0-39-cloud-arm64
 CPU Model    : KVM Virtual Machine
 CPU Cores    : 4 @  MHz aarch64  Cache
 CPU Flags    : AES-NI Enabled & VM-x/AMD-V Disabled
 Load Average : 0.14, 0.13, 0.09
 Total Space  : 196G (84G ~46% used)
 Total RAM    : 24003 MB (11809 MB + 4087 MB Buff in use)
 Total SWAP   : 1024 MB (314 MB in use)
 IPv4/IPv6    : ✔ Online / ❌ Offline
 Uptime       : 12 days 18:16
---------------------------------------------------------------------------
 Location     : United States, Chicago (Illinois)
 ASN & ISP    : AS31898, Oracle Corporation / Oracle Corporation
---------------------------------------------------------------------------

 ## Geekbench v6 CPU Benchmark:

  Single Core : 1122  (VERY GOOD)
   Multi Core : 3609
    CPU Steal : 0.00%

 ## IO Test

 CPU Speed:
    bzip2     : 115 MB/s (Steal: 0.00%)
   sha256     : 279 MB/s (Steal: 0.00%)
   md5sum     : 448 MB/s (Steal: 0.00%)

 RAM Speed:
   Avg. write : 2867.2 MB/s
   Avg. read  : 5734.4 MB/s

 Disk Speed:
   1st run    : 411 MB/s
   2nd run    : 394 MB/s
   3rd run    : 395 MB/s
   -----------------------
   Average    : 400.0 MB/s

 ## Global Speedtest.net

 Location                       Upload           Download         Ping   
---------------------------------------------------------------------------
 Nearby                         1868.52 Mbit/s   2079.14 Mbit/s   8.274 ms
---------------------------------------------------------------------------
 USA, New York (Starry)         773.78 Mbit/s    1552.67 Mbit/s  18.696 ms
 USA, Chicago (Windstream)      1677.69 Mbit/s   1944.35 Mbit/s  1.590 ms
 USA, Houston (Comcast)         550.01 Mbit/s    1248.54 Mbit/s  28.170 ms
 USA, Miami (Frontier)          398.37 Mbit/s    939.13 Mbit/s   42.825 ms
 USA, Los Angeles (Windstream)  306.53 Mbit/s    629.81 Mbit/s   56.645 ms
 UK, London (Structured Com)    192.92 Mbit/s    495.98 Mbit/s   91.195 ms
 France, Paris (KEYYO)          154.24 Mbit/s    155.29 Mbit/s   96.040 ms
 Germany, Berlin (DNS:NET)      167.11 Mbit/s    348.12 Mbit/s   106.375 ms
 Spain, Madrid (MasMovil)       151.13 Mbit/s    124.73 Mbit/s   117.890 ms
 Italy, Rome (Unidata)          141.64 Mbit/s    103.90 Mbit/s   124.285 ms
 India, Mumbai (Tatasky)        18.28 Mbit/s     12.11 Mbit/s    326.915 ms
 Singapore (MyRepublic)         57.54 Mbit/s     12.92 Mbit/s    204.533 ms
 Japan, Tsukuba (SoftEther)     108.33 Mbit/s    241.44 Mbit/s   165.276 ms
 Australia, Sydney (Telstra)    102.64 Mbit/s    104.88 Mbit/s   177.275 ms
 RSA, Randburg (MTN SA)         22.19 Mbit/s     45.86 Mbit/s    264.193 ms
 Brazil, Sao Paulo (TIM)        134.93 Mbit/s    74.36 Mbit/s    129.660 ms
---------------------------------------------------------------------------

 Finished in : 13 min 19 sec
 Timestamp   : 2025-09-23 11:57:03 GMT
 Saved in    : /root/speedtest.log

 Share results:
 - https://www.speedtest.net/result/18260986594.png
 - https://browser.geekbench.com/v6/cpu/14012322
```text

## Where to get a cheap VPS

Looking for an affordable and reliable VPS? [UpCloud](https://upcloud.com/) is an excellent choice! New users can get a **€25 bonus** when they register using our promo link or code `BEE3CJ`. With servers starting from just €3.5 for 1GB RAM, this bonus effectively gives you over **7 months of free usage**!

UpCloud offers a wide range of locations including Australia, Germany, Spain, Finland, Netherlands, Poland, Sweden, Singapore, United Kingdom, and USA.

Register now via [this link](https://signup.upcloud.com/?promo=BEE3CJ) or enter Promo code: `BEE3CJ` during registration to claim your bonus!

# Credits 

Thanks to @MasonR @sayem314 for the code
