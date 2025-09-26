#!/usr/bin/env bash

bench_v="v1.8.3"
bench_d="2025-09-26"
about() {
    echo ""
    echo " ========================================================= "
    echo " \            Speedtest https://bench.laset.com          / "
    echo " \    System info, Geekbench, I/O test and speedtest     / "
    echo " \                  $bench_v    $bench_d                 / "
    echo " ========================================================= "
    echo ""
}

cleanup() {
    # Remove temporary files
    rm -f tools.py 2>/dev/null # Removed speedtest.py
    rm -rf "$benchram" 2>/dev/null
}

cancel() {
    echo ""
    next;
    echo " Abort ..."
    echo " Cleanup ..."
    cleanup;
    echo " Done"
    exit 0
}

error_exit() {
    echo ""
    echo " Error: $1"
    echo " Cleanup ..."
    cleanup;
    echo " Done"
    exit 1
}

trap cancel SIGINT
trap 'error_exit "Unexpected error occurred"' SIGTERM

benchram="$HOME/tmpbenchram"
NULL="/dev/null"
LAST_SPEEDTEST_URL="" # Global variable to store the last Speedtest result URL

# Global variables for total traffic
TOTAL_DOWNLOAD_TRAFFIC_MB=0
TOTAL_UPLOAD_TRAFFIC_MB=0
TOTAL_PACKET_LOSS=0 # New global variable for total packet loss
SPEEDTEST_COUNT=0   # New global variable to count speed tests

# determine architecture of host
ARCH=$(uname -m)
if [[ $ARCH = *x86_64* ]]; then
    # host is running a 64-bit kernel
    ARCH="x64"
elif [[ $ARCH = *i?86* ]]; then
    # host is running a 32-bit kernel
    ARCH="x86"
elif [[ $ARCH = *aarch64* || $ARCH = *arm64* ]]; then
    # host is running ARM64 architecture
    ARCH="arm64"
elif [[ $ARCH = *armv7* || $ARCH = *armhf* ]]; then
    # host is running ARM 32-bit architecture
    ARCH="arm"
else
    # host is running a non-supported kernel
    echo -e "Architecture $ARCH might have limited support."
    ARCH="unknown"
fi

echostyle(){
    if hash tput 2>"$NULL"; then
        echo " $(tput setaf 6)$1$(tput sgr0)"
        echo " $1" >> "$log"
    else
        echo " $1" | tee -a "$log"
    fi
}

benchinit() {
    # check release
    if [ -f /etc/redhat-release ]; then
        if grep -q "AlmaLinux" /etc/redhat-release; then
            release="almalinux"
        elif grep -q "Rocky Linux" /etc/redhat-release; then
            release="rocky"
        else
            release="centos"
        fi
    elif [ -f /etc/almalinux-release ]; then
        release="almalinux"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "almalinux"; then
        release="almalinux"
    elif cat /etc/issue | grep -Eqi "rocky"; then # Added Rocky Linux check for /etc/issue
        release="rocky"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "almalinux"; then
        release="almalinux"
    elif cat /proc/version | grep -Eqi "rocky"; then # Added Rocky Linux check for /proc/version
        release="rocky"
    fi

    # check OS
    #if [ "${release}" == "centos" ]; then
    #                echo "Checking OS ... [ok]"
    #else
    #                echo "Error: This script must be run on CentOS!"
    #		exit 1
    #fi
    #echo -ne "\e[1A"; echo -ne "\e[0K\r"
    
    # check root
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root!"
    fi
    

    # Function to install packages based on distribution
    install_package() {
        local package_name=$1
        local package_path=$2
        
        if [ ! -e "$package_path" ]; then
            echo " Installing $package_name ..."
            if [[ "${release}" == "centos" || "${release}" == "almalinux" || "${release}" == "rocky" ]]; then # Added rocky
                dnf -y install "$package_name" > /dev/null 2>&1 || yum -y install "$package_name" > /dev/null 2>&1
            elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
                apt-get update -y > /dev/null 2>&1
                apt-get -y install "$package_name" > /dev/null 2>&1
            else
                echo " Unknown distribution, trying apt-get and yum..."
                apt-get -y install "$package_name" > /dev/null 2>&1 || yum -y install "$package_name" > /dev/null 2>&1
            fi
            echo -ne "\e[1A"; echo -ne "\e[0K\r"
        fi
    }

    # Check and install required packages
    install_package "python3" "/usr/bin/python3"
    install_package "jq" "/usr/bin/jq" # Install jq for JSON parsing
	install_package "bc" "/usr/bin/bc" # Install bc for floating point arithmetic
    
    # Set python3 as default if needed (for RHEL-based systems)
    if [[ "${release}" == "centos" || "${release}" == "almalinux" || "${release}" == "rocky" ]] && [ -e '/usr/bin/python3' ]; then # Added rocky
        alternatives --set python3 /usr/bin/python3 > /dev/null 2>&1 || true
    fi
    
    install_package "curl" "/usr/bin/curl"
    install_package "wget" "/usr/bin/wget"
    install_package "bzip2" "/usr/bin/bzip2"
    install_package "tar" "/usr/bin/tar"

    # Install official Speedtest CLI
    if ! command -v speedtest &> /dev/null; then
        echo " Installing official Speedtest CLI ..." | tee -a "$log"
        # Removed: echo -ne "\e[1A"; echo -ne "\e[0K\r" # This might interfere with tee output

        if [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
            echo "  Adding Speedtest CLI repository for Debian/Ubuntu..." | tee -a "$log"
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash 2>&1 | tee -a "$log"
            echo "  Updating package lists..." | tee -a "$log"
            apt-get update -y 2>&1 | tee -a "$log"
            echo "  Installing speedtest package..." | tee -a "$log"
            apt-get -y install speedtest 2>&1 | tee -a "$log"
        elif [[ "${release}" == "centos" || "${release}" == "almalinux" || "${release}" == "rocky" || "${release}" == "fedora" ]]; then
            echo "  Adding Speedtest CLI repository for RHEL-based systems..." | tee -a "$log"
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash 2>&1 | tee -a "$log"
            echo "  Updating package lists..." | tee -a "$log"
            dnf update -y 2>&1 | tee -a "$log" || yum update -y 2>&1 | tee -a "$log"
            echo "  Installing speedtest package..." | tee -a "$log"
            dnf -y install speedtest 2>&1 | tee -a "$log" || yum -y install speedtest 2>&1 | tee -a "$log"
        else
            # Fallback for other distributions using the generic script
            echo "  Attempting generic Speedtest CLI installation for unknown distribution..." | tee -a "$log"
            curl -s https://install.speedtest.net/app/cli/install.sh | bash 2>&1 | tee -a "$log"
        fi

        # Verify installation
        if ! command -v speedtest &> /dev/null; then
            error_exit "Failed to install Speedtest CLI. Please check the log for details."
        else
            echo " Speedtest CLI installed successfully." | tee -a "$log"
        fi
    fi

    # install tools.py
    if  [ ! -e 'tools.py' ]; then
        echo " Installing tools.py ..."
        wget --no-check-certificate https://raw.githubusercontent.com/laset-com/speedtest/master/tools.py > /dev/null 2>&1
        echo -ne "\e[1A"; echo -ne "\e[0K\r"
    fi
    chmod a+rx tools.py

    sleep 5

    # start
    start=$(date +%s) 
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
    printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
}
next2() {
    printf "%-57s\n" "-" | sed 's/\s/-/g'
}

delete() {
    echo -ne "\e[1A"; echo -ne "\e[0K\r"
}

# Helper function to convert "X.XX unit" to MB (no longer used for speedtest output parsing)
convert_to_mb() {
    local value_unit="$1"
    local value=$(echo "$value_unit" | awk '{print $1}')
    local unit=$(echo "$value_unit" | awk '{print $2}')
    local mb_value=0

    case "$unit" in
        "KB") mb_value=$(awk "BEGIN {printf \"%.2f\", $value / 1024}") ;;
        "MB") mb_value=$(awk "BEGIN {printf \"%.2f\", $value}") ;;
        "GB") mb_value=$(awk "BEGIN {printf \"%.2f\", $value * 1024}") ;;
        "TB") mb_value=$(awk "BEGIN {printf \"%.2f\", $value * 1024 * 1024}") ;;
        *) mb_value=0 ;; # Handle unknown units
    esac
    echo "$mb_value"
}

speed_test(){
    local nodeName=$2
    # Use --accept-license --accept-gdpr for the first run of the official Speedtest CLI
    # Use --format=json to get machine-readable output
    local speedtest_cmd="speedtest --accept-license --accept-gdpr --format=json"
    local json_output
    local REDownload_mbps
    local reupload_mbps
    local relatency
    local current_result_url
    local download_total_bytes
    local upload_total_bytes
    local download_mb
    local upload_mb
    local packet_loss # New variable for packet loss

    if [[ $1 == '' ]]; then
        # Default test (nearby server)
        json_output=$($speedtest_cmd 2>&1)
    else
        # Server-specific test
        json_output=$($speedtest_cmd -s "$1" 2>&1)
    fi

    # Check if the output is valid JSON and contains expected data
    if echo "$json_output" | jq -e '.type == "result"' >/dev/null 2>&1; then
        # Parse JSON output
        REDownload_mbps=$(echo "$json_output" | jq -r '.download.bandwidth / 125000') # Convert bytes/sec to Mbps
        reupload_mbps=$(echo "$json_output" | jq -r '.upload.bandwidth / 125000')   # Convert bytes/sec to Mbps
        relatency=$(echo "$json_output" | jq -r '.ping.latency')
        current_result_url=$(echo "$json_output" | jq -r '.result.url // ""') # Use // "" to handle null/missing URL
        packet_loss=$(echo "$json_output" | jq -r '.packetLoss // 0') # Extract packet loss

        download_total_bytes=$(echo "$json_output" | jq -r '.download.bytes // 0')
        upload_total_bytes=$(echo "$json_output" | jq -r '.upload.bytes // 0')

        # Convert total bytes to MB (decimal)
        download_mb=$(awk "BEGIN {printf \"%.2f\", $download_total_bytes / 1000000}")
        upload_mb=$(awk "BEGIN {printf \"%.2f\", $upload_total_bytes / 1000000}")

        # Accumulate in global variables
        TOTAL_DOWNLOAD_TRAFFIC_MB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_DOWNLOAD_TRAFFIC_MB + $download_mb}")
        TOTAL_UPLOAD_TRAFFIC_MB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_UPLOAD_TRAFFIC_MB + $upload_mb}")
        TOTAL_PACKET_LOSS=$(awk "BEGIN {printf \"%.2f\", $TOTAL_PACKET_LOSS + $packet_loss}") # Accumulate packet loss
        SPEEDTEST_COUNT=$((SPEEDTEST_COUNT + 1)) # Increment test count

        # Store the last result URL globally if it's a "Nearby" test (or the first one)
        if [[ $1 == '' ]]; then
            LAST_SPEEDTEST_URL="$current_result_url"
        fi

        # Format speeds and latency for display
        local formatted_download=$(printf "%.2f Mbps" "$REDownload_mbps")
        local formatted_upload=$(printf "%.2f Mbps" "$reupload_mbps")
        local formatted_latency=$(printf "%.2f ms" "$relatency")
        local formatted_packet_loss=$(printf "%.0f%%" "$packet_loss") # Format packet loss as percentage

        # Original script had a check for latency > 50 and adding an asterisk.
        # Apply asterisk only for "Nearby" server
        if [[ "$nodeName" == "Nearby"* ]] && (( $(echo "$relatency > 50" | bc -l) )); then
            formatted_latency="*"${formatted_latency}
        fi

        # Check if download speed is greater than 0 for printing
        if (( $(echo "$REDownload_mbps > 0" | bc -l) )); then
            printf "%-17s%-17s%-17s%-7s%-7s\n" " ${nodeName}" "${formatted_upload}" "${formatted_download}" "${formatted_latency}" "${formatted_packet_loss}" | tee -a "$log"
        else
            # If download speed is 0 or less, it's likely an error or very poor connection
            printf "%-17s%-17s%-17s%-7s%-7s\n" " ${nodeName}" "ERROR" "ERROR" "ERROR" "ERROR" | tee -a "$log"
            echo "--- Speedtest CLI raw output for ${nodeName} (Error/Zero Speed) ---" | tee -a "$log"
            echo "$json_output" | tee -a "$log"
            echo "-----------------------------------------------------" | tee -a "$log"
        fi
    else
        local cerror="ERROR"
        printf "%-17s%-17s%-17s%-7s%-7s\n" " ${nodeName}" "ERROR" "ERROR" "ERROR" "ERROR" | tee -a "$log"
        echo "--- Speedtest CLI raw output for ${nodeName} (Error) ---" | tee -a "$log"
        echo "$json_output" | tee -a "$log"
        echo "-----------------------------------------------------" | tee -a "$log"
    fi
}

# Function to print total traffic used
print_total_traffic() {
    local total_sum_mb=$(awk "BEGIN {printf \"%.2f\", $TOTAL_DOWNLOAD_TRAFFIC_MB + $TOTAL_UPLOAD_TRAFFIC_MB}")
    local total_download_gb=$(awk "BEGIN {printf \"%.2f\", $TOTAL_DOWNLOAD_TRAFFIC_MB / 1024}")
    local total_upload_gb=$(awk "BEGIN {printf \"%.2f\", $TOTAL_UPLOAD_TRAFFIC_MB / 1024}")
    local total_sum_gb=$(awk "BEGIN {printf \"%.2f\", $total_sum_mb / 1024}")
    local avg_packet_loss=$(awk "BEGIN {if ($SPEEDTEST_COUNT > 0) printf \"%.2f\", $TOTAL_PACKET_LOSS / $SPEEDTEST_COUNT; else print \"0.00\"}")

    echo "" | tee -a "$log"
    echostyle "## Total Traffic Used"
    echo "" | tee -a "$log"
    echo -e " Total Downloaded    : ${total_download_gb} GB (${TOTAL_DOWNLOAD_TRAFFIC_MB} MB)" | tee -a "$log"
    echo -e " Total Uploaded      : ${total_upload_gb} GB (${TOTAL_UPLOAD_TRAFFIC_MB} MB)" | tee -a "$log"
    echo -e " Total Sum           : ${total_sum_gb} GB (${total_sum_mb} MB)" | tee -a "$log"
    echo -e " Average Packet Loss : ${avg_packet_loss}%" | tee -a "$log" # Display average packet loss
    echo "" | tee -a "$log"

    # Reset global variables for subsequent runs if the script were to be called multiple times in one session
    TOTAL_DOWNLOAD_TRAFFIC_MB=0
    TOTAL_UPLOAD_TRAFFIC_MB=0
    TOTAL_PACKET_LOSS=0 # Reset packet loss
    SPEEDTEST_COUNT=0   # Reset test count
}


print_speedtest() {
    echo "" | tee -a "$log"
    echostyle "## Global Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-32s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                        '
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '21016' 'USA, New York (Starry)        '
    speed_test '17384' 'USA, Chicago (Windstream)     '
    speed_test '1763' 'USA, Houston (Comcast)        '
    speed_test '14237' 'USA, Miami (Frontier)         '
    speed_test '18401' 'USA, Los Angeles (Windstream) '
    speed_test '11445' 'UK, London (Structured Com)   '
    speed_test '27961' 'France, Paris (KEYYO)         '
    speed_test '20507' 'Germany, Berlin (DNS:NET)     '
    speed_test '21378' 'Spain, Madrid (MasMovil)      '
    speed_test '395' 'Italy, Rome (Unidata)         '
    speed_test '23647' 'India, Mumbai (Tatasky)       '
    speed_test '5935' 'Singapore (MyRepublic)        '
    speed_test '7139' 'Japan, Tsukuba (SoftEther)    '
    speed_test '2629' 'Australia, Sydney (Telstra)   '
    speed_test '15722' 'RSA, Randburg (MTN SA)        '
    speed_test '3068' 'Brazil, Sao Paulo (TIM)       '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_usa() {
    echo "" | tee -a "$log"
    echostyle "## USA Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-33s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                         '
    printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '21016' 'USA, New York (Starry)         '
    speed_test '1774' 'USA, Boston (Comcast)          '
    speed_test '1775' 'USA, Baltimore, MD (Comcast)   '
    speed_test '17387' 'USA, Atlanta (Windstream)      '
    speed_test '14237' 'USA, Miami (Frontier)          '
    speed_test '1764' 'USA, Nashville (Comcast)       '
    speed_test '10152' 'USA, Indianapolis (CenturyLink)'
    speed_test '27834' 'USA, Cleveland (Windstream)    '
    speed_test '1778' 'USA, Detroit, MI (Comcast)     '
    speed_test '17384' 'USA, Chicago (Windstream)      '
    speed_test '4557' 'USA, St. Louis (Elite Fiber)   '
    speed_test '2917' 'USA, Minneapolis (US Internet) '
    speed_test '13628' 'USA, Kansas City (Nocix)       '
    speed_test '1763' 'USA, Houston (Comcast)         '
    speed_test '10051' 'USA, Denver (Comcast)          '
    speed_test '16869' 'USA, Albuquerque (Plateau Tel) '
    speed_test '28800' 'USA, Phoenix (PhoenixNAP)      '
    speed_test '1781' 'USA, Salt Lake City (Comcast)  '
    speed_test '1782' 'USA, Seattle (Comcast)         '
    speed_test '1783' 'USA, San Francisco (Comcast)   '
    speed_test '18401' 'USA, Los Angeles (Windstream)  '
    speed_test '980' 'USA, Anchorage (Alaska Com)    '
    speed_test '24031' 'USA, Honolulu (Hawaiian Telcom)'

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_in() {
    echo "" | tee -a "$log"
    echostyle "## India Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-33s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                         '
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '7236' 'India, New Delhi (iForce)      '
    speed_test '23647' 'India, Mumbai (Tatasky)        '
    speed_test '16086' 'India, Nagpur (optbb)          '
    speed_test '12309' 'India, Patna (Max-tech)        '
    speed_test '14314' 'India, Kolkata (Meghbela)      '
    speed_test '27524' 'India, Visakhapatnam (Alliance)'
    speed_test '2679' 'India, Hyderabad (Airtel)      '
    speed_test '10024' 'India, Madurai (Niss Broadband)'

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_europe() {
    echo "" | tee -a "$log"
    echostyle "## Europe Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-34s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                          '
    printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '11445' 'UK, London (Structured Com)     '
    speed_test '29076' 'Netherlands, Amsterdam (XS News)'
    speed_test '20507' 'Germany, Berlin (DNS:NET)       '
    speed_test '31470' 'Germany, Munich (Telekom)       '
    speed_test '26852' 'Sweden, Stockholm (SUNET)       '
    speed_test '8018' 'Norway, Oslo (NextGenTel)       '
    speed_test '27961' 'France, Paris (KEYYO)           '
    speed_test '21378' 'Spain, Madrid (MasMovil)        '
    speed_test '395' 'Italy, Rome (Unidata)           '
    speed_test '30620' 'Czechia, Prague (O2)            '
    speed_test '12390' 'Austria, Vienna (A1)            '
    speed_test '7103' 'Poland, Warsaw (ISP Emitel)     '
    speed_test '30813' 'Ukraine, Kyiv (KyivStar)        '
    speed_test '5834' 'Latvia, Riga (Bite)             '
    speed_test '4290' 'Romania, Bucharest (iNES)       '
    speed_test '1727' 'Greece, Athens (GRNET)          '
    speed_test '32575' 'Turkey, Urfa (Firatnet)         '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_asia() {
    echo "" | tee -a "$log"
    echostyle "## Asia Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-34s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                          '
    printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '16475' 'India, New Delhi (Weebo)        '
    speed_test '23647' 'India, Mumbai (Tatasky)         '
    speed_test '12329' 'Sri Lanka, Colombo (Mobitel)    '
    speed_test '31336' 'Bangladesh, Dhaka (Banglalink)  '
    speed_test '24514' 'Myanmar, Yangon (TrueNET)       '
    speed_test '26845' 'Laos, Vientaine (Mangkone)      '
    speed_test '13871' 'Thailand, Bangkok (CAT Telecom) '
    speed_test '5828' 'Cambodia, Phnom Penh (SINET)    '
    speed_test '9903' 'Vietnam, Hanoi (Viettel)        '
    speed_test '27261' 'Malaysia, Kuala Lumpur (Extreme)'
    speed_test '5935' 'Singapore (MyRepublic)          '
    speed_test '7582' 'Indonesia, Jakarta (Telekom)    '
    speed_test '7167' 'Philippines, Manila (PLDT)      '
    speed_test '16176' 'Hong Kong (HGC Global)          '
    speed_test '13506' 'Taiwan, Taipei (TAIFO)          '
    speed_test '7139' 'Japan, Tsukuba (SoftEther)      '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_sa() {
    echo "" | tee -a "$log"
    echostyle "## South America Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-37s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-84s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                             '
    printf "%-84s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '3068' 'Brazil, Sao Paulo (TIM)            '
    speed_test '11102' 'Brazil, Fortaleza (Connect)        '
    speed_test '18126' 'Brazil, Manaus (Claro)             '
    speed_test '15018' 'Colombia, Bogota (Tigoune)         '
    speed_test '31043' 'Ecuador, Ambato (EXTREME)          '
    speed_test '5272' 'Peru, Lima (Fiberluxperu)          '
    speed_test '1053' 'Bolivia, La Paz (Nuevatel)         '
    speed_test '6776' 'Paraguay, Asuncion (TEISA)         '
    speed_test '21436' 'Chile, Santiago (Movistar)         '
    speed_test '5181' 'Argentina, Buenos Aires (Claro)    '
    speed_test '31687' 'Argentina, Cordoba (Colsecor)      '
    speed_test '20212' 'Uruguay, Montevideo (Movistar)     '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_au() {
    echo "" | tee -a "$log"
    echostyle "## Australia & New Zealand Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-32s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                        '
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '2629' 'Australia, Sydney (Telstra)   '
    speed_test '2225' 'Australia, Melbourne (Telstra)'
    speed_test '2604' 'Australia, Brisbane (Telstra) '
    speed_test '18247' 'Australia, Adelaide (Vocus)   '
    speed_test '22006' 'Australia, Hobart (TasmaNet)  '
    speed_test '22036' 'Australia, Darwin (Telstra)   '
    speed_test '2627' 'Australia, Perth (Telstra)    '
    speed_test '5539' 'NZ, Auckland (2degrees)       '
    speed_test '11326' 'NZ, Wellington (Spark)        '
    speed_test '4934' 'NZ, Christchurch (Vodafone)   '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_ukraine() {
    echo "" | tee -a "$log"
    echostyle "## Ukraine Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-32s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                        '
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '29112' 'Ukraine, Kyiv (Datagroup)     '
    speed_test '30813' 'Ukraine, Kyiv (KyivStar)      '
    speed_test '14887' 'Ukraine, Lviv (UARNet)        '
    speed_test '29259' 'Ukraine, Lviv (KyivStar)      '
    speed_test '2445' 'Ukraine, Lviv (KOMiTEX)       '
    speed_test '3022' 'Ukraine, Uzhgorod (TransCom)  '
    speed_test '19332' 'Ukraine, Chernivtsi (C.T.Net) '
    speed_test '3861' 'Ukraine, Zhytomyr (DKS)       '
    speed_test '8633' 'Ukraine, Cherkasy (McLaut)    '
    speed_test '20285' 'Ukraine, Kharkiv (Maxnet)     '
    speed_test '20953' 'Ukraine, Dnipro (Trifle)      '
    speed_test '2796' 'Ukraine, Odesa (Black Sea)    '
    speed_test '26725' 'Ukraine, Mariupol (CityLine)  '
    speed_test '21617' 'Ukraine, Yalta (Yaltanet)     '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_lviv() {
    echo "" | tee -a "$log"
    echostyle "## Lviv Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-26s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-74s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                  '
    printf "%-74s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '14887' 'Ukraine, Lviv (UARNet)  '
    speed_test '29259' 'Ukraine, Lviv (KyivStar)'
    speed_test '2445' 'Ukraine, Lviv (KOMiTEX) '
    speed_test '12786' 'Ukraine, Lviv (ASTRA)   '
    speed_test '1204' 'Ukraine, Lviv (Network) '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_meast() {
    echo "" | tee -a "$log"
    echostyle "## Middle East Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-30s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-78s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                      '
    printf "%-78s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '610' 'Cyprus, Limassol (PrimeTel) '
    speed_test '2434' 'Israel, Haifa (013Netvision)'
    speed_test '1689' 'Egypt, Cairo (Vodafone)     '
    speed_test '9137' 'Lebanon, Tripoli (Be-Wise)  '
    speed_test '22129' 'UAE, Dubai (i3D)            '
    speed_test '24742' 'Qatar, Doha (Ooredoo)       '
    speed_test '608' 'SA, Riyadh (STC)            '
    speed_test '1912' 'Bahrain, Manama (Zain)      '
    speed_test '18512' 'Iran, Tehran (MCI)          '

    print_total_traffic # Print total traffic after all speed tests
}

print_speedtest_china() {
    echo "" | tee -a "$log"
    echostyle "## China Speedtest.net"
    echo "" | tee -a "$log"
    printf "%-32s%-17s%-17s%-7s%-7s\n" " Location" "Upload" "Download" "Ping" "Loss" | tee -a "$log"
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
        speed_test '' 'Nearby                        '
    printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
    speed_test '5396' 'Suzhou (China Telecom 5G)     '
    speed_test '26352' 'Nanjing (China Telecom 5G)    '
    speed_test '71313' 'Xuzhou (中国电信)              '
    speed_test '36663' 'Zhenjiang (China Telecom 5G)  '

    print_total_traffic # Print total traffic after all speed tests
}

geekbench4() {
    if [[ $ARCH = *x86* ]]; then # 32-bit
    echo -e "\nGeekbench 4 cannot run on 32-bit architectures. Skipping the test"
    elif [[ $ARCH = *aarch64* || $ARCH = *arm64* ]]; then # ARM64
    echo -e "\nGeekbench 4 is not compatible with ARM64 architectures. Skipping the test"
    else
    echo "" | tee -a "$log"
    echo -e " Performing Geekbench v4 CPU Benchmark test. Please wait..."


    # Start steal time measurement
    local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
    
    GEEKBENCH_PATH=$HOME/geekbench
    mkdir -p "$GEEKBENCH_PATH"
    curl -s https://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz  | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    GEEKBENCH_TEST=$("$GEEKBENCH_PATH"/geekbench4 2>/dev/null | grep "https://browser")
    GEEKBENCH_URL=$(echo -e "$GEEKBENCH_TEST" | head -1)
    GEEKBENCH_URL_CLAIM=$(echo "$GEEKBENCH_URL" | awk '{ print $2 }')
    GEEKBENCH_URL=$(echo "$GEEKBENCH_URL" | awk '{ print $1 }')
    sleep 20
    GEEKBENCH_SCORES=$(curl -s "$GEEKBENCH_URL" | grep "span class='score'")
    GEEKBENCH_SCORES_SINGLE=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $3 }')
    GEEKBENCH_SCORES_MULTI=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $7 }')
    
    # End steal time measurement
    local steal_end=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_end=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
    
    # Calculate steal time
    local steal_diff=$((steal_end - steal_start))
    local total_diff=$((total_end - total_start))
    
    # Calculate steal time percentage
    if [[ $total_diff -gt 0 ]]; then
        STEAL_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($steal_diff * 100) / $total_diff}")
    else
        STEAL_PERCENT="0.00"
    fi
    
    if [[ $GEEKBENCH_SCORES_SINGLE -le 1700 ]]; then
        grank="(POOR)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 1700 && $GEEKBENCH_SCORES_SINGLE -le 2500 ]]; then
        grank="(FAIR)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 2500 && $GEEKBENCH_SCORES_SINGLE -le 3500 ]]; then
        grank="(GOOD)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 3500 && $GEEKBENCH_SCORES_SINGLE -le 4500 ]]; then
        grank="(VERY GOOD)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 4500 && $GEEKBENCH_SCORES_SINGLE -le 6000 ]]; then
        grank="(EXCELLENT)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 6000 && $GEEKBENCH_SCORES_SINGLE -le 7000 ]]; then
        grank="(THE BEAST)"
    else
        grank="(MONSTER)"
    fi
    
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    echostyle "## Geekbench v4 CPU Benchmark:"
    echo "" | tee -a "$log"
    echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a "$log"
    echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a "$log"
    echo -e "    CPU Steal : ${STEAL_PERCENT}%" | tee -a "$log"
    [ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
    echo "" | tee -a "$log"
    echo -e " Cooling down..."
    sleep 9
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    echo -e " Ready to continue..."
    sleep 3
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    fi
}

geekbench5() {
    if [[ $ARCH = *x86* ]]; then # 32-bit
    echo -e "\nGeekbench 5 cannot run on 32-bit architectures. Skipping the test"
    else
    echo "" | tee -a "$log"
    echo -e " Performing Geekbench v5 CPU Benchmark test. Please wait..."


    # Start steal time measurement
    local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')

    GEEKBENCH_PATH=$HOME/geekbench
    mkdir -p "$GEEKBENCH_PATH"
    if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
        curl -s https://cdn.geekbench.com/Geekbench-5.5.1-LinuxARMPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    elif [[ $(uname -m) == "riscv64" ]]; then
        curl -s https://cdn.geekbench.com/Geekbench-5.5.1-LinuxRISCVPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    else
        curl -s https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    fi
    GEEKBENCH_TEST=$("$GEEKBENCH_PATH"/geekbench5 2>/dev/null | grep "https://browser")
    GEEKBENCH_URL=$(echo -e "$GEEKBENCH_TEST" | head -1)
    GEEKBENCH_URL_CLAIM=$(echo "$GEEKBENCH_URL" | awk '{ print $2 }')
    GEEKBENCH_URL=$(echo "$GEEKBENCH_URL" | awk '{ print $1 }')
    sleep 20
    GEEKBENCH_SCORES=$(curl -s "$GEEKBENCH_URL" | grep "div class='score'")
    GEEKBENCH_SCORES_SINGLE=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $3 }')
    GEEKBENCH_SCORES_MULTI=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(<|>)" '{ print $7 }')

    # End steal time measurement
    local steal_end=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_end=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
    
    # Calculate steal time
    local steal_diff=$((steal_end - steal_start))
    local total_diff=$((total_end - total_start))
    
    # Calculate steal time percentage
    if [[ $total_diff -gt 0 ]]; then
        STEAL_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($steal_diff * 100) / $total_diff}")
    else
        STEAL_PERCENT="0.00"
    fi
    
    if [[ $GEEKBENCH_SCORES_SINGLE -le 300 ]]; then
        grank="(POOR)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 300 && $GEEKBENCH_SCORES_SINGLE -le 500 ]]; then
        grank="(FAIR)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 500 && $GEEKBENCH_SCORES_SINGLE -le 700 ]]; then
        grank="(GOOD)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 700 && $GEEKBENCH_SCORES_SINGLE -le 1000 ]]; then
        grank="(VERY GOOD)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 1000 && $GEEKBENCH_SCORES_SINGLE -le 1500 ]]; then
        grank="(EXCELLENT)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 1500 && $GEEKBENCH_SCORES_SINGLE -le 2000 ]]; then
        grank="(THE BEAST)"
    else
        grank="(MONSTER)"
    fi
    
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    echostyle "## Geekbench v5 CPU Benchmark:"
    echo "" | tee -a "$log"
    echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a "$log"
    echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a "$log"
    echo -e "    CPU Steal : ${STEAL_PERCENT}%" | tee -a "$log"
    [ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
    echo "" | tee -a "$log"
    echo -e " Cooling down..."
    sleep 9
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    echo -e " Ready to continue..."
    sleep 3
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    fi
}

geekbench6() {
    if [[ $ARCH = *x86* ]]; then # 32-bit
    echo -e "\nGeekbench 6 cannot run on 32-bit architectures. Skipping the test"
    else
    echo "" | tee -a "$log"
    echo -e " Performing Geekbench v6 CPU Benchmark test. Please wait..."


    # Start steal time measurement
    local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')

    GEEKBENCH_PATH=$HOME/geekbench
    mkdir -p "$GEEKBENCH_PATH"
    if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
        curl -s https://cdn.geekbench.com/Geekbench-6.5.0-LinuxARMPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    elif [[ $(uname -m) == "riscv64" ]]; then
        curl -s https://cdn.geekbench.com/Geekbench-6.5.0-LinuxRISCVPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    else
        curl -s https://cdn.geekbench.com/Geekbench-6.5.0-Linux.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
    fi
    GEEKBENCH_TEST=$("$GEEKBENCH_PATH"/geekbench6 2>/dev/null | grep "https://browser")
    GEEKBENCH_URL=$(echo -e "$GEEKBENCH_TEST" | head -1)
    GEEKBENCH_URL_CLAIM=$(echo "$GEEKBENCH_URL" | awk '{ print $2 }')
    GEEKBENCH_URL=$(echo "$GEEKBENCH_URL" | awk '{ print $1 }')
    sleep 15
    GEEKBENCH_SCORES=$(curl -s "$GEEKBENCH_URL" | grep "div class='score'")
    GEEKBENCH_SCORES_SINGLE=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $3 }')
    GEEKBENCH_SCORES_MULTI=$(echo "$GEEKBENCH_SCORES" | awk -v FS="(<|>)" '{ print $7 }')

    # End steal time measurement
    local steal_end=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_end=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
    
    # Calculate steal time
    local steal_diff=$((steal_end - steal_start))
    local total_diff=$((total_end - total_start))
    
    # Calculate steal time percentage
    if [[ $total_diff -gt 0 ]]; then
        STEAL_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($steal_diff * 100) / $total_diff}")
    else
        STEAL_PERCENT="0.00"
    fi
    
    if [[ $GEEKBENCH_SCORES_SINGLE -le 400 ]]; then
        grank="(POOR)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 400 && $GEEKBENCH_SCORES_SINGLE -le 660 ]]; then
        grank="(FAIR)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 660 && $GEEKBENCH_SCORES_SINGLE -le 925 ]]; then
        grank="(GOOD)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 925 && $GEEKBENCH_SCORES_SINGLE -le 1350 ]]; then
        grank="(VERY GOOD)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 1350 && $GEEKBENCH_SCORES_SINGLE -le 2000 ]]; then
        grank="(EXCELLENT)"
    elif [[ $GEEKBENCH_SCORES_SINGLE -ge 2000 && $GEEKBENCH_SCORES_SINGLE -le 2600 ]]; then
        grank="(THE BEAST)"
    else
        grank="(MONSTER)"
    fi
    
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    echostyle "## Geekbench v6 CPU Benchmark:"
    echo "" | tee -a "$log"
    echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a "$log"
    echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a "$log"
    echo -e "    CPU Steal : ${STEAL_PERCENT}%" | tee -a "$log"
    [ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
    echo "" | tee -a "$log"
    echo -e " Cooling down..."
    sleep 9
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    echo -e " Ready to continue..."
    sleep 3
    echo -ne "\e[1A"; echo -ne "\033[0K\r"
    fi
}

geekbench() {
    totalram="$( free -m | grep Mem | awk 'NR=1 {print $2}' )"
    if [[ $totalram -le 1000 ]]; then
        geekbench4
    elif [[ $totalram -ge 1000 && $totalram -le 2000 ]]; then
        geekbench5
    else
        geekbench6
    fi
}

calc_disk() {
    local total_size=0
    local array=$@"
    for size in "${array[@]}"
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo "${size:0:${#size}-1}"`
        [ "`echo "${size:(-1)}"`" == "K" ] && size=0
        [ "`echo "${size:(-1)}"`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo "${size:(-1)}"`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo "${size:(-1)}"`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo "${total_size}"
}

power_time() {

    result=$(smartctl -a $(result=$(cat /proc/mounts) && echo $(echo "$result" | awk '/data=ordered/{print $1}') | awk '{print $1}') 2>&1) && power_time=$(echo "$result" | awk '/Power_On/{print $10}') && echo "$power_time"
}

install_smart() {
    # install smartctl
    if  [ ! -e '/usr/sbin/smartctl' ]; then
        echo "Installing Smartctl ..."

        if [[ "${release}" == "centos" || "${release}" == "almalinux" || "${release}" == "rocky" ]]; then
            dnf update -y > "$NULL" 2>&1 || yum update -y > "$NULL" 2>&1 # Added update for RHEL-based
            dnf -y install smartmontools > "$NULL" 2>&1 || yum -y install smartmontools > "$NULL" 2>&1
        elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
            apt-get update -y > "$NULL" 2>&1
            apt-get -y install smartmontools > "$NULL" 2>&1
        elif [[ "${release}" == "arch" ]]; then
            pacman -Sy --noconfirm smartmontools > "$NULL" 2>&1
        elif [[ "${release}" == "suse" ]]; then
            zypper --non-interactive install smartmontools > "$NULL" 2>&1
        else
            # Fallback for unknown distributions
            apt-get update -y > "$NULL" 2>&1
            apt-get -y install smartmontools > "$NULL" 2>&1 || \
            yum -y install smartmontools > "$NULL" 2>&1 || \
            dnf -y install smartmontools > "$NULL" 2>&1 || \
            pacman -Sy --noconfirm smartmontools > "$NULL" 2>&1 || \
            zypper --non-interactive install smartmontools > "$NULL" 2>&1
        fi      
    fi
}

# test if the host has IPv4/IPv6 connectivity
[[ ! -z $LOCAL_CURL ]] && IP_CHECK_CMD="curl -s -m 4" || IP_CHECK_CMD="wget -qO- -T 4"
IPV4_CHECK=$((ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -4 icanhazip.com 2> /dev/null)
IPV6_CHECK=$((ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -6 icanhazip.com 2> /dev/null)
if [[ -z "$IPV4_CHECK" && -z "$IPV6_CHECK" ]]; then
    echo -e
    echo -e "Warning: Both IPv4 AND IPv6 connectivity were not detected. Check for DNS issues..."
fi

ip_info(){
    # no jq
    country=$(curl -s https://ipapi.co/country_name/)
    city=$(curl -s https://ipapi.co/city/)
    asn=$(curl -s https://ipapi.co/asn/)
    org=$(curl -s https://ipapi.co/org/)
    countryCode=$(curl -s https://ipapi.co/country/)
    region=$(curl -s https://ipapi.co/region/)

    echo -e " ASN & ISP            : $asn" | tee -a "$log"
    echo -e " Organization         : $org" | tee -a "$log"
    echo -e " Location             : $city, $country ($countryCode)" | tee -a "$log"
    echo -e " Region               : $region" | tee -a "$log"
}

ip_info4(){
    isp=$(python3 tools.py geoip isp)
    as_tmp=$(python3 tools.py geoip as)
    asn=$(echo "$as_tmp" | awk -F ' ' '{print $1}')
    org=$(python3 tools.py geoip org)
    country=$(python3 tools.py geoip country)
    city=$(python3 tools.py geoip city)
    #countryCode=$(python3 tools.py geoip countryCode)
    region=$(python3 tools.py geoip regionName)

    echo -e " Location     : $country, $city ($region)" | tee -a "$log"
    #echo -e " Region       : $region" | tee -a $log
    echo -e " ASN & ISP    : $asn, $isp / $org" | tee -a "$log"
    #echo -e " Organization : $org" | tee -a $log

    # Removed redundant rm -rf tools.py, it's handled in cleanup
}

machine_location(){
    isp=$(python3 tools.py geoip isp)
    as_tmp=$(python3 tools.py geoip as)
    asn=$(echo "$as_tmp" | awk -F ' ' '{print $1}')
    org=$(python3 tools.py geoip org)
    country=$(python3 tools.py geoip country)
    city=$(python3 tools.py geoip city)
    #countryCode=$(python3 tools.py geoip countryCode)
    region=$(python3 tools.py geoip regionName)	

    echo -e " Machine location: $country, $city ($region)"
    echo -e " ISP & ORG: $asn, $isp / $org"

    # Removed redundant rm -rf tools.py, it's handled in cleanup
}

virt_check(){
    if hash ifconfig 2>"$NULL"; then
        local eth=$(ifconfig)
    fi

    # Use systemd-detect-virt if available for more reliable detection
    if hash systemd-detect-virt 2>"$NULL"; then
        local detected_virt=$(systemd-detect-virt)
        if [[ "$detected_virt" != "none" ]]; then
            if [[ "$detected_virt" == "kvm" ]]; then
                virtual="KVM" # Capitalize KVM
            else
                virtual=$(echo "$detected_virt" | awk '{print toupper(substr($0,1,1))substr($0,2)}') # Capitalize first letter
            fi
        else
            virtual="Dedicated"
        fi
    else
        local virtualx=$(dmesg) 2>"$NULL"
        
        # Check for containers
        if grep docker /proc/1/cgroup -qa; then
            virtual="Docker"
        elif grep lxc /proc/1/cgroup -qa; then
            virtual="Lxc"
        elif grep -qa container=lxc /proc/1/environ; then
            virtual="Lxc"
        elif [[ -f /proc/user_beancounters ]]; then
            virtual="OpenVZ"
        # Check for virtual machines
        elif [[ "$virtualx" == *kvm-clock* ]]; then
            virtual="KVM"
        elif [[ "$cname" == *KVM* ]]; then
            virtual="KVM"
        elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
            virtual="VMware"
        elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
            virtual="Parallels"
        elif [[ "$virtualx" == *VirtualBox* ]]; then
            virtual="VirtualBox"
        elif [[ -e /proc/xen ]]; then
            virtual="Xen"
        elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
            if [[ "$sys_product" == *"Virtual Machine"* ]]; then
                if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
                    virtual="Hyper-V"
                else
                    virtual="Microsoft Virtual Machine"
                fi
            fi
        # Additional virtualization checks for ARM64
        elif [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
            # Check for KVM virtualization on ARM64
            if grep -q "KVM" /proc/cpuinfo 2>"$NULL" || grep -q "kvm" /proc/interrupts 2>"$NULL"; then
                virtual="KVM"
            # Check for Xen virtualization on ARM64
            elif grep -q "xen" /proc/interrupts 2>"$NULL" || [[ -d /proc/xen ]]; then
                virtual="Xen"
            # Check for virtualization via /sys interface
            elif [[ -f /sys/class/dmi/id/product_name ]]; then
                local product_name=$(cat /sys/class/dmi/id/product_name 2>"$NULL")
                if [[ "$product_name" == *"Virtual"* || "$product_name" == *"VM"* || "$product_name" == *"Cloud"* ]]; then
                    virtual="VM"
                else
                    virtual="Dedicated"
                fi
            else
                virtual="Dedicated"
            fi
        else
            virtual="Dedicated"
        fi
    fi
}

power_time_check(){
    echo -ne " Power time of disk   : "
    install_smart
    ptime=$(power_time)
    echo -e "$ptime Hours"
}

freedisk() {
    # Check available disk space
    #spacename=$( df -m . | awk 'NR==2 {print $1}' )
    #spacenamelength=$(echo ${spacename} | awk '{print length($0)}')
    #if [[ $spacenamelength -gt 20 ]]; then
       #	freespace=$( df -m . | awk 'NR==3 {print $3}' )
    #else
    #	freespace=$( df -m . | awk 'NR==2 {print $4}' )
    #fi
    freespace=$( df -m . | awk 'NR==2 {print $4}' )
    if [[ $freespace == "" ]]; then
        freespace=$( df -m . | awk 'NR==3 {print $3}' )
    fi
    if [[ $freespace -gt 1024 ]]; then
        printf "%s" $((1024*2))
    elif [[ $freespace -gt 512 ]]; then
        printf "%s" $((512*2))
    elif [[ $freespace -gt 256 ]]; then
        printf "%s" $((256*2))
    elif [[ $freespace -gt 128 ]]; then
        printf "%s" $((128*2))
    else
        printf "1"
    fi
}

print_system_info() {
    echo -e " OS           : $opsy ($lbit Bit)" | tee -a "$log"
    echo -e " Virt/Kernel  : $virtual / $kern" | tee -a "$log"
    echo -e " CPU Model    : $cname" | tee -a "$log"
    echo -e " CPU Cores    : $cores @ $freq MHz $arch $corescache Cache" | tee -a "$log"
    echo -e " CPU Flags    : $cpu_aes & $cpu_virt" | tee -a "$log"
    echo -e " Load Average : $load" | tee -a "$log"
    echo -e " Total Space  : $hdd ($hddused ~$hddfree used)" | tee -a "$log"
    echo -e " Total RAM    : $tram MB ($uram MB + $bram MB Buff in use)" | tee -a "$log"
    echo -e " Total SWAP   : $swap MB ($uswap MB in use)" | tee -a "$log"
    [[ -z "$IPV4_CHECK" ]] && ONLINE="\xE2\x9D\x8C Offline / " || ONLINE="\xE2\x9C\x94 Online / "
    [[ -z "$IPV6_CHECK" ]] && ONLINE+="\xE2\x9D\x8C Offline" || ONLINE+="\xE2\x9C\x94 Online"
    echo -e " IPv4/IPv6    : $ONLINE" | tee -a "$log"
    echo -e " Uptime       : $up" | tee -a "$log"
    printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a "$log"
}

get_system_info() {
    # Detect CPU model with ARM64 support
    if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
        # Try to get CPU model for ARM64
        cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
        
        # If model is not defined, try other fields
        if [[ -z "$cname" ]]; then
            cname=$(awk -F: '/Hardware/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
        fi
        
        # If still not defined, try other sources
        if [[ -z "$cname" ]]; then
            if [[ -f /sys/devices/virtual/dmi/id/product_name ]]; then
                cname=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
            fi
        fi
        
        # If still not defined, set as "Unknown ARM64 Processor"
        if [[ -z "$cname" ]]; then
            cname="Unknown ARM64 Processor"
        fi
    else
        # Standard detection for x86_64
        cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    fi
    
    # Detect number of cores with ARM64 support
    if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
        cores=$(grep -c ^processor /proc/cpuinfo)
    else
        cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    fi
    
    freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    corescache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    cpu_aes=$(cat /proc/cpuinfo | grep aes)
    [[ -z "$cpu_aes" ]] && cpu_aes="AES-NI Disabled" || cpu_aes="AES-NI Enabled"
    cpu_virt=$(cat /proc/cpuinfo | grep 'vmx\|svm')
    [[ -z "$cpu_virt" ]] && cpu_virt="VM-x/AMD-V Disabled" || cpu_virt="VM-x/AMD-V Enabled"
    tram=$( free -m | awk '/Mem/ {print $2}' )
    uram=$( free -m | awk '/Mem/ {print $3}' )
    bram=$( free -m | awk '/Mem/ {print $6}' )
    swap=$( free -m | awk '/Swap/ {print $2}' )
    uswap=$( free -m | awk '/Swap/ {print $3}' )
    up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d:%d\n",a,b,c)}' /proc/uptime )
    load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    opsy=$( get_opsy )
    arch=$( uname -m )
    lbit=$( getconf LONG_BIT )
    kern=$( uname -r )
    #ipv6=$( wget -qO- -t1 -T2 ipv6.icanhazip.com )
    #disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' ))
    #disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' ))
    #disk_total_size=$( calc_disk ${disk_size1[@]} )
    #disk_used_size=$( calc_disk ${disk_size2[@]} )
    hdd=$(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total -h | grep total | awk '{ print $2 }')
    hddused=$(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total -h | grep total | awk '{ print $3 }')
    hddfree=$(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total -h | grep total | awk '{ print $5 }')
    #tcp congestion control
    #tcpctrl=$( sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )

    #tmp=$(python3 tools.py disk 0)
    #disk_total_size=$(echo $tmp | sed s/G//)
    #tmp=$(python3 tools.py disk 1)
    #disk_used_size=$(echo $tmp | sed s/G//)

    virt_check
}

write_test() {
    (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

averageio() {
    ioraw1=$( echo "$1" | awk 'NR==1 {print $1}' )
        [ "`echo "$1" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
    ioraw2=$( echo "$2" | awk 'NR==1 {print $1}' )
        [ "`echo "$2" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
    ioraw3=$( echo "$3" | awk 'NR==1 {print $1}' )
        [ "`echo "$3" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
    ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
    ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
    printf "%s" "$ioavg"
}

measure_steal_time() {
    # Measure CPU steal time for the specified period
    local duration=$1
    local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
    
    sleep "$duration"
    
    local steal_end=$(grep 'steal' /proc/stat | awk '{print $2}')
    local total_end=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
    
    local steal_diff=$((steal_end - steal_start))
    local total_diff=$((total_end - total_start))
    
    # Calculate steal time percentage
    if [[ $total_diff -gt 0 ]]; then
        local steal_percent=$(awk "BEGIN {printf \"%.2f\", ($steal_diff * 100) / $total_diff}")
        echo "$steal_percent"
    else
        echo "0.00"
    fi
}

cpubench() {
    if hash "$1" 2>"$NULL"; then
        # Measure steal time before the test
        local steal_before=$(measure_steal_time 1)
        
        # Run performance test
        io=$( ( dd if=/dev/zero bs=512K count="$2" | "$1" ) 2>&1 | grep 'copied' | awk -F, '{io=$NF} END {print io}' )
        
        # Measure steal time after the test
        local steal_after=$(measure_steal_time 1)
        
        # Save average steal time value
        steal_avg=$(awk "BEGIN {printf \"%.2f\", ($steal_before + $steal_after) / 2}")
        
        if [[ $io != *"."* ]]; then
            printf " %4i %s (Steal: %s%%)" "${io% *}" "${io##* }" "$steal_avg"
        else
            printf " %4i.%s (Steal: %s%%)" "${io%.*}" "${io#*.}" "$steal_avg"
        fi
    else
        printf " %s not found on system." "$1"
    fi
}

iotest() {
    echostyle "## IO Test"
    echo "" | tee -a "$log"

    # start testing
    writemb=$(freedisk)
    if [[ $writemb -gt 512 ]]; then
        writemb_size="$(( writemb / 2 / 2 ))MB"
        writemb_cpu="$(( writemb / 2 ))"
    else
        writemb_size="$writemb"MB
        writemb_cpu=$writemb
    fi

    # CPU Speed test
    echostyle "CPU Speed:"
    echo "    bzip2     :$( cpubench bzip2 "$writemb_cpu" )" | tee -a "$log" 
    echo "   sha256     :$( cpubench sha256sum "$writemb_cpu" )" | tee -a "$log"
    echo "   md5sum     :$( cpubench md5sum "$writemb_cpu" )" | tee -a "$log"
    echo "" | tee -a "$log"

    # RAM Speed test
    # set ram allocation for mount
    tram_mb="$( free -m | grep Mem | awk 'NR=1 {print $2}' )"
    if [[ tram_mb -gt 1900 ]]; then
        sbram=1024M
        sbcount=2048
    else
        sbram=$(( tram_mb / 2 ))M
        sbcount=$tram_mb
    fi
    [[ -d $benchram ]] || mkdir "$benchram"
    mount -t tmpfs -o size="$sbram" tmpfs "$benchram"/
    echostyle "RAM Speed:"
    iow1=$( ( dd if=/dev/zero of="$benchram"/zero bs=512K count="$sbcount" ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    ior1=$( ( dd if="$benchram"/zero of="$NULL" bs=512K count="$sbcount"; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    iow2=$( ( dd if=/dev/zero of="$benchram"/zero bs=512K count="$sbcount" ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    ior2=$( ( dd if="$benchram"/zero of="$NULL" bs=512K count="$sbcount"; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    iow3=$( ( dd if=/dev/zero of="$benchram"/zero bs=512K count="$sbcount" ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    ior3=$( ( dd if="$benchram"/zero of="$NULL" bs=512K count="$sbcount"; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    echo "   Avg. write : $(averageio "$iow1" "$iow2" "$iow3") MB/s" | tee -a "$log"
    echo "   Avg. read  : $(averageio "$ior1" "$ior2" "$ior3") MB/s" | tee -a "$log"
    rm "$benchram"/zero
    umount "$benchram"
    rm -rf "$benchram"
    echo "" | tee -a "$log"
    
    # Disk test
    #echostyle "Disk Speed:" 
    #if [[ $writemb != "1" ]]; then
    #	io=$( ( dd bs=512K count=$writemb if=/dev/zero of=test; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    #	echo "   I/O Speed  :$io" | tee -a $log

    #	io=$( ( dd bs=512K count=$writemb if=/dev/zero of=test oflag=direct; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
    #	echo "   I/O Direct :$io" | tee -a $log
    #else
    #	echo "   Not enough space to test." | tee -a $log
    #fi
    #echo "" | tee -a $log
}


write_io() {
    writemb=$(freedisk)
    writemb_size="$(( writemb / 2 ))MB"
    if [[ "$writemb_size" == "1024MB" ]]; then
        writemb_size="1.0GB"
    fi

    if [[ $writemb != "1" ]]; then
        echostyle "Disk Speed:"
        echo -n "   1st run    : " | tee -a "$log"
        io1=$( write_test "$writemb" )
        echo -e "$io1" | tee -a "$log"
        echo -n "   2nd run    : " | tee -a "$log"
        io2=$( write_test "$writemb" )
        echo -e "$io2" | tee -a "$log"
        echo -n "   3rd run    : " | tee -a "$log"
        io3=$( write_test "$writemb" )
        echo -e "$io3" | tee -a "$log"
        ioraw1=$( echo "$io1" | awk 'NR==1 {print $1}' )
        [ "`echo "$io1" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
        ioraw2=$( echo "$io2" | awk 'NR==1 {print $1}' )
        [ "`echo "$io2" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
        ioraw3=$( echo "$io3" | awk 'NR==1 {print $1}' )
        [ "`echo "$io3" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
        ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
        ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
        echo -e "   -----------------------" | tee -a "$log"
        echo -e "   Average    : $ioavg MB/s" | tee -a "$log"
    else
        echo -e " Not enough space!"
    fi
}

print_end_time() {
    echo "" | tee -a "$log"
    end=$(date +%s) 
    time=$(( end - start ))
    if [[ $time -gt 60 ]]; then
        min=$(expr $time / 60)
        sec=$(expr $time % 60)
        echo -ne " Finished in : ${min} min ${sec} sec"
    else
        echo -ne " Finished in : ${time} sec"
    fi
    #echo -ne "\n Current time : "
    #echo $(date +%Y-%m-%d" "%H:%M:%S)
    printf '\n'
    utc_time=$(date -u '+%F %T')
    echo " Timestamp   : $utc_time GMT" | tee -a "$log"
    #echo " Finished!"
    echo " Saved in    : $log"
    echo "" | tee -a "$log"
}

print_intro() {
    printf "%-75s\n" "-" | sed 's/\s/-/g'
    printf ' Region: %s  https://bench.laset.com %s %s \n' "$region_name" "$bench_v" "$bench_d" | tee -a "$log"
    printf " Usage : curl -sL bench.laset.com | bash -s -- -%s\n" "$region_name" | tee -a "$log"
}

sharetest() {
    echo " Share results:"
    # result_speed is no longer set from the official Speedtest CLI output
    # echo " - $result_speed" | tee -a $log
    log_preupload
    # The official Speedtest CLI provides its own share URL, so these paste services are not strictly needed.
    # case $1 in
    # #'ubuntu')
    # #	share_link=$( curl -v --data-urlencode "content@$log_up" -d "poster=speedtest.sh" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 | \
    # #		grep "Location" | awk '{print "https://paste.ubuntu.com"$3}' );;
    # #'haste' )
    # #	share_link=$( curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}' );;
    # # 'clbin' )
    # 	#share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
    # 	#sprunge_link=$(curl -sF 'sprunge=<-' https://sprunge.us < $log);;
    # esac

    # Replace "http://" with "https://"
    #share_link=$(echo "$sprunge_link" | sed 's/http:/https:/')

    # print result info
    [ ! -z "$LAST_SPEEDTEST_URL" ] && echo " - $LAST_SPEEDTEST_URL" | tee -a "$log" # Added official Speedtest result URL
    echo " - $GEEKBENCH_URL" | tee -a "$log"
    # echo " - $share_link"
    echo ""
    rm -f "$log_up"

}

log_preupload() {
    log_up="$HOME/speedtest_upload.log"
    true > "$log_up"
    $(cat speedtest.log 2>&1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > "$log_up")
}

get_ip_whois_org_name(){
    #ip=$(curl -s ip.sb)
    result=$(curl -s https://rest.db.ripe.net/search.json?query-string=$(curl -s ip.sb))
    #org_name=$(echo "$result" | jq '.objects.object.[1].attributes.attribute.[1].value' | sed 's/\"//g')
    org_name=$(echo "$result" | jq '.objects.object[1].attributes.attribute[1]' | sed 's/\"//g')
    echo "$org_name";
}

# Removed pingtest function as official Speedtest CLI provides latency data.
# pingtest() {
# 	local ping_link=$(echo ${1#*//} | cut -d"/" -f1)

# 	# Send three pings and capture the output
# 	local ping_output=$(ping -w 1 -c 3 -q $ping_link | grep 'rtt')

# 	# Extract the avg value from the output
# 	local ping_avg=$(echo "$ping_output" | awk -F'/' '{print $6}')

# 	# get download speed and print
# 	if [[ $ping_avg == "" ]]; then
#   	  printf "ping error!"
# 	else
# 	  printf "%d.%s ms" "${ping_avg%.*}" "${ping_avg#*.}"
# 	fi
# }

cleanup() {
    rm -f test_file_*;
    # rm -f speedtest.py; # Removed
    rm -f speedtest.sh;
    rm -f tools.py;
    rm -f ip_json.json;
    rm -f geekbench_claim.url;
    rm -rf geekbench;
}

bench_all(){
    region_name="Global"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

usa_bench(){
    region_name="USA"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_usa; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

in_bench(){
    region_name="India"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_in; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

europe_bench(){
    region_name="Europe"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_europe; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

asia_bench(){
    region_name="Asia"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_asia; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

china_bench(){
    region_name="China"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_china; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

sa_bench(){
    region_name="South-America"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_sa; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

au_bench(){
    region_name="AU-NZ"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_au; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

ukraine_bench(){
    region_name="Ukraine"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_ukraine; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}
lviv_bench(){
    region_name="Lviv"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_lviv; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}
meast_bench(){
    region_name="Middle-East"
    print_intro;
    benchinit;
    next;
    get_system_info;
    print_system_info;
    ip_info4;
    next;
    geekbench;
    iotest;
    write_io;
    print_speedtest_meast; # This function now calls print_total_traffic internally
    next;
    print_end_time;
    cleanup;
    sharetest clbin;
}

log="$HOME/speedtest.log"
true > "$log"

case $1 in
    'info'|'i'|'-i'|'--i'|'-info'|'--info' )
        about;sleep 3;next;get_system_info;print_system_info;next;cleanup;;
    'version'|'v'|'-v'|'--v'|'-version'|'--version')
        next;about;next;cleanup;;
      'gb4'|'-gb4'|'--gb4'|'geek4'|'-geek4'|'--geek4' )
        next;geekbench4;next;cleanup;;
       'gb5'|'-gb5'|'--gb5'|'geek5'|'-geek5'|'--geek5' )
        next;geekbench5;next;cleanup;;
         'gb6'|'-gb6'|'--gb6'|'geek6'|'-geek6'|'--geek6' )
        next;geekbench6;next;cleanup;;
    'gb'|'-gb'|'--gb'|'geek'|'-geek'|'--geek' )
        next;geekbench;next;cleanup;;
    'io'|'-io'|'--io'|'ioping'|'-ioping'|'--ioping' )
        next;iotest;write_io;next;cleanup;;
    'speed'|'-speed'|'--speed'|'-speedtest'|'--speedtest'|'-speedcheck'|'--speedcheck' )
        about;benchinit;machine_location;print_speedtest;next;cleanup;;
    'usas'|'-usas'|'uss'|'-uss'|'uspeed'|'-uspeed' )
        about;benchinit;machine_location;print_speedtest_usa;next;cleanup;;
    'eus'|'-eus'|'es'|'-es'|'espeed'|'-espeed' )
        about;benchinit;machine_location;print_speedtest_europe;next;cleanup;;
    'as'|'-as'|'aspeed'|'-aspeed' )
        about;benchinit;machine_location;print_speedtest_asia;next;cleanup;;
    'aus'|'-aus'|'auspeed'|'-auspeed' )
        about;benchinit;machine_location;print_speedtest_au;next;cleanup;;
    'sas'|'-sas'|'saspeed'|'-saspeed' )
        about;benchinit;machine_location;print_speedtest_sa;next;cleanup;;
    'mes'|'-mes'|'mespeed'|'-mespeed' )
        about;benchinit;machine_location;print_speedtest_meast;next;cleanup;;
    'ins'|'-ins'|'inspeed'|'-inspeed' )
        about;benchinit;machine_location;print_speedtest_in;next;cleanup;;
    'cns'|'-cns'|'cnspeed'|'-cnspeed' )
        about;benchinit;machine_location;print_speedtest_china;next;cleanup;;
    'uas'|'-uas'|'uaspeed'|'-uaspeed' )
        about;benchinit;machine_location;print_speedtest_ukraine;next;cleanup;;
    'lvivs'|'-lvivs' )
        about;benchinit;machine_location;print_speedtest_lviv;next;cleanup;;
    'ip'|'-ip'|'--ip'|'geoip'|'-geoip'|'--geoip' )
        about;benchinit;next;ip_info4;next;cleanup;;
    'a'|'-a'|'about'|'-about'|'--about' )
        about;next;cleanup;;
      'all'|'-all'|'bench'|'-bench'|'--bench'|'-Global' )
        bench_all;;
    'usa'|'-usa'|'--usa'|'us'|'-us'|'--us'|'USA'|'-USA'|'--USA' )
        usa_bench;;
    'in'|'-india'|'--in'|'in'|'-in'|'IN'|'-IN'|'--IN' )
        in_bench;;
    'europe'|'-europe'|'--europe'|'eu'|'-eu'|'--eu'|'Europe'|'-Europe'|'--Europe' )
        europe_bench;;
    'asia'|'-asia'|'--asia'|'Asia'|'-Asia'|'--Asia' )
        asia_bench;;
    'china'|'-china'|'--china'|'mjj'|'-mjj'|'cn'|'-cn'|'--cn'|'China'|'-China'|'--China' )
        china_bench;;
    'au'|'-au'|'nz'|'-nz'|'AU'|'-AU'|'NZ'|'-NZ'|'-AU-NZ' )
        au_bench;;
    'sa'|'-sa'|'--sa'|'-South-America' )
        sa_bench;;
    'ukraine'|'-ukraine'|'--ukraine'|'ua'|'-ua'|'--ua'|'ukr'|'-ukr'|'--ukr'|'Ukraine'|'-Ukraine'|'--Ukraine' )
        ukraine_bench;;
    'lviv'|'-lviv'|'--lviv'|'-Lviv'|'--Lviv' )
        lviv_bench;;
    'M-East'|'-M-East'|'--M-East'|'-m-east'|'--m-east'|'-meast'|'--meast'|'-Middle-East'|'-me' )
        meast_bench;;
    '-s'|'--s'|'share'|'-share'|'--share' )
        bench_all;
        is_share="share"
        if [[ $2 == "" ]]; then
            sharetest clbin;
        else
            sharetest "$2";
        fi
        ;;
    'debug'|'-d'|'--d'|'-debug'|'--debug' )
        get_ip_whois_org_name;;
*)
    bench_all;;
esac



if [[  ! $is_share == "share" ]]; then
    case $2 in
        'share'|'-s'|'--s'|'-share'|'--share' )
            if [[ $3 == '' ]]; then
                sharetest clbin;
            else
                sharetest "$3";
            fi
            ;;
    esac
fi
