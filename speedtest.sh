#!/usr/bin/env bash

bench_v="v1.8.1"
bench_d="2025-09-21"

# Global variables for temporary directories created by mktemp
GEEKBENCH_TEMP_DIR=""
RAMDISK_TEMP_DIR=""

about() {
	echo ""
	echo " ========================================================= "
	echo " \            Speedtest https://bench.laset.com            / "
	echo " \    System info, Geekbench, I/O test and speedtest     / "
	echo " \                  $bench_v    $bench_d                 / "
	echo " ========================================================= "
	echo ""
}

cleanup() {
	# Remove temporary files created in the current directory
	rm -f speedtest.py tools.py 2>/dev/null
	rm -f ip_json.json 2>/dev/null
	rm -f geekbench_claim.url 2>/dev/null
	rm -f test_file_* 2>/dev/null
	
	# Remove temporary directories created by mktemp
	if [[ -n "$GEEKBENCH_TEMP_DIR" && -d "$GEEKBENCH_TEMP_DIR" ]]; then
		rm -rf "$GEEKBENCH_TEMP_DIR" 2>/dev/null
	fi
	if [[ -n "$RAMDISK_TEMP_DIR" && -d "$RAMDISK_TEMP_DIR" ]]; then
		umount "$RAMDISK_TEMP_DIR" 2>/dev/null # Attempt to unmount before removing
		rm -rf "$RAMDISK_TEMP_DIR" 2>/dev/null
	fi
	
	# Remove the old fixed 'geekbench' directory if it exists (for backward compatibility)
	rm -rf geekbench 2>/dev/null
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

NULL="/dev/null"

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
	if hash tput 2>$NULL; then
		echo " $(tput setaf 6)$1$(tput sgr0)"
		echo " $1" >> $log
	else
		echo " $1" | tee -a $log
	fi
}

benchinit() {
	# check release
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		if [[ "$ID" == "debian" ]]; then
			release="debian"
		elif [[ "$ID" == "ubuntu" ]]; then
			release="ubuntu"
		elif [[ "$ID" == "centos" ]]; then
			release="centos"
		elif [[ "$ID" == "almalinux" ]]; then
			release="almalinux"
		elif [[ "$ID" == "rocky" ]]; then
			release="rocky"
		elif [[ "$ID" == "arch" ]]; then # Added Arch Linux detection
			release="arch"
		elif [[ "$ID" == "fedora" ]]; then # Added Fedora detection
			release="fedora"
		elif [[ "$ID" == "opensuse" || "$ID" == "sles" ]]; then # Added SUSE detection
			release="suse"
		elif [[ "$ID_LIKE" == *debian* ]]; then # Fallback for Debian-like
			release="debian"
		elif [[ "$ID_LIKE" == *centos* || "$ID_LIKE" == *rhel* || "$ID_LIKE" == *fedora* ]]; then # Fallback for RHEL-like
			release="centos" # Group RHEL-likes under centos for package management
		elif [[ "$ID_LIKE" == *arch* ]]; then # Fallback for Arch-like
			release="arch"
		elif [[ "$ID_LIKE" == *suse* ]]; then # Fallback for SUSE-like
			release="suse"
		else
			release="unknown"
		fi
	# Fallback to older methods if /etc/os-release is not present or ID is not recognized
	elif [ -f /etc/redhat-release ]; then
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
	elif cat /etc/issue | grep -Eqi "rocky"; then
		release="rocky"
	elif cat /proc/version | grep -Eqi "debian"; then
		release="debian"
	elif cat /proc/version | grep -Eqi "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -Eqi "almalinux"; then
		release="almalinux"
	elif cat /proc/version | grep -Eqi "rocky"; then
		release="rocky"
	else
		release="unknown" # Final fallback if no known release file is found
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
			if [[ "${release}" == "centos" || "${release}" == "almalinux" || "${release}" == "rocky" || "${release}" == "fedora" ]]; then
				dnf -y install $package_name > /dev/null 2>&1 || yum -y install $package_name > /dev/null 2>&1
			elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
				apt-get update -y > /dev/null 2>&1
				apt-get -y install $package_name > /dev/null 2>&1
			elif [[ "${release}" == "arch" ]]; then
				pacman -Sy --noconfirm $package_name > /dev/null 2>&1
			elif [[ "${release}" == "suse" ]]; then
				zypper --non-interactive install $package_name > /dev/null 2>&1
			else
				echo " Unknown distribution, trying apt-get, yum, dnf, pacman, and zypper..."
				apt-get -y install $package_name > /dev/null 2>&1 || \
				yum -y install $package_name > /dev/null 2>&1 || \
				dnf -y install $package_name > /dev/null 2>&1 || \
				pacman -Sy --noconfirm $package_name > /dev/null 2>&1 || \
				zypper --non-interactive install $package_name > /dev/null 2>&1
			fi
			echo -ne "\e[1A"; echo -ne "\e[0K\r"
		fi
	}

	# Check and install required packages
	install_package "python3" "/usr/bin/python3"
	
	# Set python3 as default if needed (for RHEL-based systems)
	if [[ "${release}" == "centos" || "${release}" == "almalinux" || "${release}" == "rocky" || "${release}" == "fedora" ]] && [ -e '/usr/bin/python3' ]; then
		alternatives --set python3 /usr/bin/python3 > /dev/null 2>&1 || true
	fi
	
	install_package "curl" "/usr/bin/curl"
	install_package "wget" "/usr/bin/wget"
	install_package "bzip2" "/usr/bin/bzip2"
	install_package "tar" "/usr/bin/tar"
	install_package "jq" "/usr/bin/jq" # Added jq installation

	# install speedtest-cli
	if  [ ! -e 'speedtest.py' ]; then
		echo " Installing Speedtest-cli ..."
		wget --no-check-certificate https://raw.githubusercontent.com/laset-com/speedtest-cli/master/speedtest.py > /dev/null 2>&1
		echo -ne "\e[1A"; echo -ne "\e[0K\r"
	fi
	chmod a+rx speedtest.py


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
    printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
}
next2() {
    printf "%-57s\n" "-" | sed 's/\s/-/g'
}

delete() {
    echo -ne "\e[1A"; echo -ne "\e[0K\r"
}

speed_test(){
	if [[ $1 == '' ]]; then
		temp=$(python3 speedtest.py --secure --share 2>&1)
		is_down=$(echo "$temp" | grep 'Download')
		result_speed=$(echo "$temp" | awk -F ' ' '/results/{print $3}')
		if [[ ${is_down} ]]; then
	        local REDownload=$(echo "$temp" | awk -F ':' '/Download/{print $2}')
	        local reupload=$(echo "$temp" | awk -F ':' '/Upload/{print $2}')
	        local relatency=$(echo "$temp" | awk -F ':' '/Hosted/{print $2}')

	        temp=$(echo "$relatency" | awk -F '.' '{print $1}')
        	if [[ ${temp} -gt 50 ]]; then
            	relatency="*"${relatency}
        	fi
	        local nodeName=$2

	        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	        	printf "%-17s%-17s%-17s%-7s\n" " ${nodeName}" "${reupload}" "${REDownload}" "${relatency}" | tee -a $log
	        fi
		else
	        local cerror="ERROR"
		fi
	else
		temp=$(python3 speedtest.py --secure --server $1 --share 2>&1)
		is_down=$(echo "$temp" | grep 'Download') 
		if [[ ${is_down} ]]; then
	        local REDownload=$(echo "$temp" | awk -F ':' '/Download/{print $2}')
	        local reupload=$(echo "$temp" | awk -F ':' '/Upload/{print $2}')
	        #local relatency=$(echo "$temp" | awk -F ':' '/Hosted/{print $2}')
	        local relatency=$(pingtest $3)
	        #temp=$(echo "$relatency" | awk -F '.' '{print $1}')
        	#if [[ ${temp} -gt 1000 ]]; then
            	#relatency=" - "
        	#fi
	        local nodeName=$2

	        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	        	printf "%-17s%-17s%-17s%-7s\n" " ${nodeName}" "${reupload}" "${REDownload}" "${relatency}" | tee -a $log
			fi
		else
	        local cerror="ERROR"
		fi
	fi
}


print_speedtest() {
	echo "" | tee -a $log
	echostyle "## Global Speedtest.net"
	echo "" | tee -a $log
	printf "%-32s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                        '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '21016' 'USA, New York (Starry)        ' 'http://speedtest-server-nyc.starry.com'
	speed_test '17384' 'USA, Chicago (Windstream)     ' 'http://chicago02.speedtest.windstream.net'
	speed_test '1763' 'USA, Houston (Comcast)        ' 'http://speedtest.pslightwave.com'
	speed_test '14237' 'USA, Miami (Frontier)         ' 'http://miami.fl.speedtest.frontier.com'
	speed_test '18401' 'USA, Los Angeles (Windstream) ' 'http://la02.speedtest.windstream.net'
	speed_test '11445' 'UK, London (Structured Com)   ' 'http://lon.host.speedtest.net'
	speed_test '27961' 'France, Paris (KEYYO)         ' 'http://perf.keyyo.net'
	speed_test '20507' 'Germany, Berlin (DNS:NET)     ' 'http://speedtest01.dns-net.de'
	speed_test '21378' 'Spain, Madrid (MasMovil)      ' 'http://speedtest-mad.masmovil.com'
	speed_test '395' 'Italy, Rome (Unidata)         ' 'http://speedtest2.unidata.it'
	speed_test '23647' 'India, Mumbai (Tatasky)       ' 'http://speedtestmum.tataskybroadband.com'
	speed_test '5935' 'Singapore (MyRepublic)        ' 'http://speedtest.myrepublic.com.sg'
	speed_test '7139' 'Japan, Tsukuba (SoftEther)    ' 'http://speedtest2.softether.co.jp'
	speed_test '2629' 'Australia, Sydney (Telstra)   ' 'http://syd1.speedtest.telstra.net'
	speed_test '15722' 'RSA, Randburg (MTN SA)        ' 'http://speedtest.rb.mtn.co.za'
	speed_test '3068' 'Brazil, Sao Paulo (TIM)       ' 'http://svstsne0101.timbrasil.com.br'
	 
	rm -rf speedtest.py
}

print_speedtest_usa() {
	echo "" | tee -a $log
	echostyle "## USA Speedtest.net"
	echo "" | tee -a $log
	printf "%-33s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-76s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                         '
	printf "%-76s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '21016' 'USA, New York (Starry)         ' 'http://speedtest-server-nyc.starry.com'
	speed_test '1774' 'USA, Boston (Comcast)          ' 'http://po-2-rur102.needham.ma.boston.comcast.net'
	speed_test '1775' 'USA, Baltimore, MD (Comcast)   ' 'http://po-1-rur101.capitolhghts.md.bad.comcast.net'
	speed_test '17387' 'USA, Atlanta (Windstream)      ' 'http://atlanta02.speedtest.windstream.net'
	speed_test '14237' 'USA, Miami (Frontier)          ' 'http://miami.fl.speedtest.frontier.com'
	speed_test '1764' 'USA, Nashville (Comcast)       ' 'http://be-304-cr23.nashville.tn.ibone.comcast.net'
	speed_test '10152' 'USA, Indianapolis (CenturyLink)' 'http://indianapolis.speedtest.centurylink.net'
	speed_test '27834' 'USA, Cleveland (Windstream)    ' 'http://cleveland02.speedtest.windstream.net'
	speed_test '1778' 'USA, Detroit, MI (Comcast)     ' 'http://ae-97-rur101.taylor.mi.michigan.comcast.net'
	speed_test '17384' 'USA, Chicago (Windstream)      ' 'http://chicago02.speedtest.windstream.net'
	speed_test '4557' 'USA, St. Louis (Elite Fiber)   ' 'http://speed.elitesystemsllc.com'
	speed_test '2917' 'USA, Minneapolis (US Internet) ' 'http://speedtest.usiwireless.com'
	speed_test '13628' 'USA, Kansas City (Nocix)       ' 'http://speedtest.nocix.net'
	speed_test '1763' 'USA, Houston (Comcast)         ' 'http://speedtest.pslightwave.com'
	speed_test '10051' 'USA, Denver (Comcast)          ' 'http://stosat-dvre-01.sys.comcast.net'
	speed_test '16869' 'USA, Albuquerque (Plateau Tel) ' 'http://speedtest4.plateautel.net'
	speed_test '28800' 'USA, Phoenix (PhoenixNAP)      ' 'http://speedtest.phoenixnap.com'
	speed_test '1781' 'USA, Salt Lake City (Comcast)  ' 'http://be-36711-ar01.saltlakecity.ut.utah.comcast.net'
	speed_test '1782' 'USA, Seattle (Comcast)         ' 'http://po-1-xar02.seattle.wa.seattle.comcast.net'
	speed_test '1783' 'USA, San Francisco (Comcast)   ' 'http://be-232-rur01.santaclara.ca.sfba.comcast.net'
	speed_test '18401' 'USA, Los Angeles (Windstream)  ' 'http://la02.speedtest.windstream.net'
	speed_test '980' 'USA, Anchorage (Alaska Com)    ' 'http://speedtest.anc.acsalaska.net'
	speed_test '24031' 'USA, Honolulu (Hawaiian Telcom)' 'http://htspeed.hawaiiantel.net'
	 
	rm -rf speedtest.py
}

print_speedtest_in() {
	echo "" | tee -a $log
	echostyle "## India Speedtest.net"
	echo "" | tee -a $log
	printf "%-33s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                         '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '7236' 'India, New Delhi (iForce)      ' 'http://speed.iforcenetworks.co.in'
	speed_test '23647' 'India, Mumbai (Tatasky)        ' 'http://speedtestmum.tataskybroadband.com'
	speed_test '16086' 'India, Nagpur (optbb)          ' 'http://speedtest.optbb.in'
	speed_test '23244' 'India, Patna (Airtel)          ' 'http://speedtestbhr1.airtel.in'
	speed_test '15697' 'India, Kolkata (RailTel)       ' 'http://kol.speedtest.rcil.gov.in'
	speed_test '27524' 'India, Visakhapatnam (Alliance)' 'http://speedtestvtz.alliancebroadband.in'
	speed_test '13785' 'India, Hyderabad (I-ON)        ' 'http://testspeed.vainavi.net'
	speed_test '10024' 'India, Madurai (Niss Broadband)' 'http://madurai.nissbroadband.com'
	rm -rf speedtest.py
}

print_speedtest_europe() {
	echo "" | tee -a $log
	echostyle "## Europe Speedtest.net"
	echo "" | tee -a $log
	printf "%-34s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                          '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '11445' 'UK, London (Structured Com)     ' 'http://lon.host.speedtest.net'
	speed_test '29076' 'Netherlands, Amsterdam (XS News)' 'http://speedtest.xsnews.nl'
	speed_test '20507' 'Germany, Berlin (DNS:NET)       ' 'http://speedtest01.dns-net.de'
	speed_test '31470' 'Germany, Munich (Telekom)       ' 'http://mue.wsqm.telekom-dienste.de'
	speed_test '26852' 'Sweden, Stockholm (SUNET)       ' 'http://fd.sunet.se'
	speed_test '8018' 'Norway, Oslo (NextGenTel)       ' 'http://sp2.nextgentel.no'
	speed_test '27961' 'France, Paris (KEYYO)           ' 'http://perf.keyyo.net'
	speed_test '21378' 'Spain, Madrid (MasMovil)        ' 'http://speedtest-mad.masmovil.com'
	speed_test '395' 'Italy, Rome (Unidata)           ' 'http://speedtest2.unidata.it'
	speed_test '30620' 'Czechia, Prague (O2)            ' 'http://ookla.o2.cz'
	speed_test '12390' 'Austria, Vienna (A1)            ' 'http://speedtest.a1.net'
	speed_test '7103' 'Poland, Warsaw (ISP Emitel)     ' 'http://speedtest.emitel.pl'
	speed_test '30813' 'Ukraine, Kyiv (KyivStar)        ' 'http://srv01-okl-kv.kyivstar.ua'
	speed_test '5834' 'Latvia, Riga (Bite)             ' 'http://213.226.139.90'
	speed_test '4290' 'Romania, Bucharest (iNES)       ' 'http://speed.ines.ro'
	speed_test '1727' 'Greece, Athens (GRNET)          ' 'http://speed-test.gr-ix.gr'
	speed_test '32575' 'Turkey, Urfa (Firatnet)         ' 'http://firatspeedtest.com'
	 
	rm -rf speedtest.py
}

print_speedtest_asia() {
	echo "" | tee -a $log
	echostyle "## Asia Speedtest.net"
	echo "" | tee -a $log
	printf "%-34s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                          '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '16475' 'India, New Delhi (Weebo)        ' 'http://sp1.weebo.in'
	speed_test '23647' 'India, Mumbai (Tatasky)         ' 'http://speedtestmum.tataskybroadband.com'
	speed_test '12329' 'Sri Lanka, Colombo (Mobitel)    ' 'http://ookla.mobitel.lk'
	speed_test '31336' 'Bangladesh, Dhaka (Banglalink)  ' 'http://speedtest1.banglalink.net'
	speed_test '24514' 'Myanmar, Yangon (TrueNET)       ' 'http://truenetisp.net'
	speed_test '26845' 'Laos, Vientaine (Mangkone)      ' 'http://speedtest.mangkone.com'
	speed_test '13871' 'Thailand, Bangkok (CAT Telecom) ' 'http://catspeedtest.net'
	speed_test '5828' 'Cambodia, Phnom Penh (SINET)    ' 'http://speedtest.sinet.com.kh'
	speed_test '9903' 'Vietnam, Hanoi (Viettel)        ' 'http://speedtestkv1a.viettel.vn'
	speed_test '27261' 'Malaysia, Kuala Lumpur (Extreme)' 'http://kl-speedtest.ebb.my'
	speed_test '5935' 'Singapore (MyRepublic)          ' 'http://speedtest.myrepublic.com.sg'
	speed_test '7582' 'Indonesia, Jakarta (Telekom)    ' 'http://jakarta.speedtest.telkom.net.id'
	speed_test '7167' 'Philippines, Manila (PLDT)      ' 'http://119.92.238.50'
	speed_test '16176' 'Hong Kong (HGC Global)          ' 'http://ookla-speedtest.hgconair.hgc.com.hk'
	speed_test '13506' 'Taiwan, Taipei (TAIFO)          ' 'http://speedtest.taifo.com.tw'
	speed_test '7139' 'Japan, Tsukuba (SoftEther)      ' 'http://speedtest2.softether.co.jp'
	 
	rm -rf speedtest.py
}

print_speedtest_sa() {
	echo "" | tee -a $log
	echostyle "## South America Speedtest.net"
	echo "" | tee -a $log
	printf "%-37s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                             '
	printf "%-80s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '3068' 'Brazil, Sao Paulo (TIM)            ' 'http://svstsne0101.timbrasil.com.br'
	speed_test '11102' 'Brazil, Fortaleza (Connect)        ' 'http://speedtest3.connectja.com.br'
	speed_test '18126' 'Brazil, Manaus (Claro)             ' 'http://spd7.claro.com.br'
	speed_test '15018' 'Colombia, Bogota (Tigoune)         ' 'http://speedtestbog1.tigo.com.co'
	speed_test '31043' 'Ecuador, Ambato (EXTREME)          ' 'http://speed.extreme.net.ec'
	speed_test '5272' 'Peru, Lima (Fiberluxperu)          ' 'http://medidor.fiberluxperu.com'
	speed_test '1053' 'Bolivia, La Paz (Nuevatel)         ' 'http://speedtest.nuevatel.com'
	speed_test '6776' 'Paraguay, Asuncion (TEISA)         ' 'http://sp1.teisa.com.py'
	speed_test '21436' 'Chile, Santiago (Movistar)         ' 'http://speedtest-h5-10g.movistarplay.cl'
	speed_test '5181' 'Argentina, Buenos Aires (Claro)    ' 'http://speedtest.claro.com.ar'
	speed_test '31687' 'Argentina, Cordoba (Colsecor)      ' 'http://speedtest.colsecor.com.ar'
	speed_test '20212' 'Uruguay, Montevideo (Movistar)     ' 'http://speedtest.movistar.com.uy'
	 
	rm -rf speedtest.py
}

print_speedtest_au() {
	echo "" | tee -a $log
	echostyle "## Australia & New Zealand Speedtest.net"
	echo "" | tee -a $log
	printf "%-32s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                        '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '2629' 'Australia, Sydney (Telstra)   ' 'http://syd1.speedtest.telstra.net'
	speed_test '2225' 'Australia, Melbourne (Telstra)' 'http://mel1.speedtest.telstra.net'
	speed_test '2604' 'Australia, Brisbane (Telstra) ' 'http://brs1.speedtest.telstra.net'
	speed_test '18247' 'Australia, Adelaide (Vocus)   ' 'http://speedtest-ade.vocus.net'
	speed_test '22006' 'Australia, Hobart (TasmaNet)  ' 'http://speedtest.tasmanet.com.au'
	speed_test '22036' 'Australia, Darwin (Telstra)   ' 'http://drw1.speedtest.telstra.net'
	speed_test '2627' 'Australia, Perth (Telstra)    ' 'http://per1.speedtest.telstra.net'
	speed_test '5539' 'NZ, Auckland (2degrees)       ' 'http://speed2.snap.net.nz'
	speed_test '11326' 'NZ, Wellington (Spark)        ' 'http://speedtest-wellington.spark.co.nz'
	speed_test '4934' 'NZ, Christchurch (Vodafone)   ' 'http://christchurch.speedtest.vodafone.co.nz'
	 
	rm -rf speedtest.py
}

print_speedtest_ukraine() {
	echo "" | tee -a $log
	echostyle "## Ukraine Speedtest.net"
	echo "" | tee -a $log
	printf "%-32s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                        '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '29112' 'Ukraine, Kyiv (Datagroup)     ' 'http://speedtest.datagroup.ua'
	speed_test '30813' 'Ukraine, Kyiv (KyivStar)      ' 'http://srv01-okl-kv.kyivstar.ua'
	speed_test '2518' 'Ukraine, Kyiv (Volia)         ' 'http://speedtest2.volia.com'
	speed_test '14887' 'Ukraine, Lviv (UARNet)        ' 'http://speedtest.uar.net'
	speed_test '29259' 'Ukraine, Lviv (KyivStar)      ' 'http://srv01-okl-lvv.kyivstar.ua'
	speed_test '2445' 'Ukraine, Lviv (KOMiTEX)       ' 'http://speedtest.komitex.net'
	speed_test '3022' 'Ukraine, Uzhgorod (TransCom)  ' 'http://speedtest.tcom.uz.ua'
	speed_test '19332' 'Ukraine, Chernivtsi (C.T.Net) ' 'http://speedtest.ctn.cv.ua'
	speed_test '3861' 'Ukraine, Zhytomyr (DKS)       ' 'http://speedtest1.dks.com.ua'
	speed_test '8633' 'Ukraine, Cherkasy (McLaut)    ' 'http://speedtest2.mclaut.com'
	speed_test '20285' 'Ukraine, Kharkiv (Maxnet)     ' 'http://speedtest.maxnet.ua'
	speed_test '20953' 'Ukraine, Dnipro (Trifle)      ' 'http://speedtest.trifle.net'
	speed_test '2796' 'Ukraine, Odesa (Black Sea)    ' 'http://speedtest.blacksea.net.ua'
	speed_test '26725' 'Ukraine, Mariupol (CityLine)  ' 'http://speedtest.cl.dn.ua'
	speed_test '2581' 'Ukraine, Yalta (KNET)         ' 'http://speedtest.knet-tele.com'
	 
	rm -rf speedtest.py
}

print_speedtest_lviv() {
	echo "" | tee -a $log
	echostyle "## Lviv Speedtest.net"
	echo "" | tee -a $log
	printf "%-26s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                  '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '14887' 'Ukraine, Lviv (UARNet)  ' 'http://speedtest.uar.net'
	speed_test '29259' 'Ukraine, Lviv (KyivStar)' 'http://srv01-okl-lvv.kyivstar.ua'
	speed_test '2445' 'Ukraine, Lviv (KOMiTEX) ' 'http://speedtest.komitex.net'
	speed_test '12786' 'Ukraine, Lviv (ASTRA)   ' 'http://speedtest.astra.in.ua'
	speed_test '1204' 'Ukraine, Lviv (Network) ' 'http://speedtest.network.lviv.ua'
	speed_test '34751' 'Ukraine, Lviv (Wenet)   ' 'http://vds.wenet.lviv.ua'
	 
	rm -rf speedtest.py
}

print_speedtest_meast() {
	echo "" | tee -a $log
	echostyle "## Middle East Speedtest.net"
	echo "" | tee -a $log
	printf "%-30s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                      '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '610' 'Cyprus, Limassol (PrimeTel) ' 'http://speedtest-node.prime-tel.com'
	speed_test '2434' 'Israel, Haifa (013Netvision)' 'http://speed2.013.net'
	speed_test '16139' 'Egypt, Cairo (Telecom Egypt)' 'http://speedtestob.orange.eg'
	speed_test '12498' 'Lebanon, Tripoli (BItarNet) ' 'http://speedtest1.wavenet-lb.net'
	speed_test '22129' 'UAE, Dubai (i3D)            ' 'http://ae.ap.speedtest.i3d.net'
	speed_test '24742' 'Qatar, Doha (Ooredoo)       ' 'http://37.186.62.40'
	speed_test '13610' 'SA, Riyadh (ITC)            ' 'http://87.101.181.146'
	speed_test '1912' 'Bahrain, Manama (Zain)      ' 'http://62.209.25.182'
	speed_test '18512' 'Iran, Tehran (MCI)          ' 'http://rhaspd2.mci.ir'
	 
	rm -rf speedtest.py
}

print_speedtest_china() {
	echo "" | tee -a $log
	echostyle "## China Speedtest.net"
	echo "" | tee -a $log
	printf "%-32s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                        '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '5396' 'Suzhou (China Telecom 5G)     ' 'http://4gsuzhou1.speedtest.jsinfo.net'
	speed_test '24447' 'ShangHai (China Unicom 5G)    ' 'http://5g.shunicomtest.com'
	speed_test '26331' 'Zhengzhou (Henan CMCC 5G)     ' 'http://5ghenan.ha.chinamobile.com'
	speed_test '29105' 'Xi"an (China Mobile 5G)       ' 'http://122.77.240.140'
	speed_test '4870' 'Changsha (China Unicom 5G)    ' 'http://220.202.152.178'
	speed_test '3633' 'Shanghai (China Telecom)      ' 'http://speedtest1.online.sh.cn'
	 
	rm -rf speedtest.py
}

geekbench4() {
	if [[ $ARCH = *x86* ]]; then # 32-bit
	echo -e "\nGeekbench 4 cannot run on 32-bit architectures. Skipping the test"
	elif [[ $ARCH = *aarch64* || $ARCH = *arm64* ]]; then # ARM64
	echo -e "\nGeekbench 4 is not compatible with ARM64 architectures. Skipping the test"
	else
	echo "" | tee -a $log
	echo -e " Performing Geekbench v4 CPU Benchmark test. Please wait..."

	# Start steal time measurement
	local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
	local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
	
	GEEKBENCH_TEMP_DIR=$(mktemp -d -t geekbench.XXXXXX) # Use global variable and specific prefix
	curl -s https://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz  | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	GEEKBENCH_TEST=$("$GEEKBENCH_TEMP_DIR"/geekbench4 2>/dev/null | grep "https://browser")
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
	echo "" | tee -a $log
	echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a $log
	echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a $log
	echo -e "    CPU Steal : ${STEAL_PERCENT}%" | tee -a $log
	[ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
	echo "" | tee -a $log
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
	echo "" | tee -a $log
	echo -e " Performing Geekbench v5 CPU Benchmark test. Please wait..."

	# Start steal time measurement
	local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
	local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')

	GEEKBENCH_TEMP_DIR=$(mktemp -d -t geekbench.XXXXXX) # Use global variable and specific prefix
	if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
		curl -s https://cdn.geekbench.com/Geekbench-5.5.1-LinuxARMPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	elif [[ $(uname -m) == "riscv64" ]]; then
		curl -s https://cdn.geekbench.com/Geekbench-5.5.1-LinuxRISCVPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	else
		curl -s https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	fi
	GEEKBENCH_TEST=$("$GEEKBENCH_TEMP_DIR"/geekbench5 2>/dev/null | grep "https://browser")
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
	echo "" | tee -a $log
	echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a $log
	echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a $log
	echo -e "    CPU Steal : ${STEAL_PERCENT}%" | tee -a $log
	[ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
	echo "" | tee -a $log
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
	echo "" | tee -a $log
	echo -e " Performing Geekbench v6 CPU Benchmark test. Please wait..."

	# Start steal time measurement
	local steal_start=$(grep 'steal' /proc/stat | awk '{print $2}')
	local total_start=$(grep '^cpu ' /proc/stat | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')

	GEEKBENCH_TEMP_DIR=$(mktemp -d -t geekbench.XXXXXX) # Use global variable and specific prefix
	if [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]]; then
		curl -s https://cdn.geekbench.com/Geekbench-6.5.0-LinuxARMPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	elif [[ $(uname -m) == "riscv64" ]]; then
		curl -s https://cdn.geekbench.com/Geekbench-6.5.0-LinuxRISCVPreview.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	else
		curl -s https://cdn.geekbench.com/Geekbench-6.5.0-Linux.tar.gz | tar xz --strip-components=1 -C "$GEEKBENCH_TEMP_DIR" &>/dev/null
	fi
	GEEKBENCH_TEST=$("$GEEKBENCH_TEMP_DIR"/geekbench6 2>/dev/null | grep "https://browser")
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
	echo "" | tee -a $log
	echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a $log
	echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a $log
	echo -e "    CPU Steal : ${STEAL_PERCENT}%" | tee -a $log
	[ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
	echo "" | tee -a $log
	echo -e " Cooling down..."
	sleep 9
	echo -ne "\e[1A"; echo -ne "\033[0K\r"
	echo -e " Ready to continue..."
	sleep 3
	echo -ne "\e[1A"; echo -ne "\033[0K\r"
	fi
}

iotest() {
	echostyle "## IO Test"
	echo "" | tee -a $log

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
	echo "    bzip2     :$( cpubench bzip2 $writemb_cpu )" | tee -a $log 
	echo "   sha256     :$( cpubench sha256sum $writemb_cpu )" | tee -a $log
	echo "   md5sum     :$( cpubench md5sum $writemb_cpu )" | tee -a $log
	echo "" | tee -a $log

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
	RAMDISK_TEMP_DIR=$(mktemp -d -t ramdisk.XXXXXX) # Corrected and using global variable
	mount -t tmpfs -o size="$sbram" tmpfs "$RAMDISK_TEMP_DIR"/
	echostyle "RAM Speed:"
	iow1=$( ( dd if=/dev/zero of="$RAMDISK_TEMP_DIR"/zero bs=512K count="$sbcount" ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior1=$( ( dd if="$RAMDISK_TEMP_DIR"/zero of="$NULL" bs=512K count="$sbcount"; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	iow2=$( ( dd if=/dev/zero of="$RAMDISK_TEMP_DIR"/zero bs=512K count="$sbcount" ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior2=$( ( dd if="$RAMDISK_TEMP_DIR"/zero of="$NULL" bs=512K count="$sbcount"; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	iow3=$( ( dd if=/dev/zero of="$RAMDISK_TEMP_DIR"/zero bs=512K count="$sbcount" ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior3=$( ( dd if="$RAMDISK_TEMP_DIR"/zero of="$NULL" bs=512K count="$sbcount"; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	echo "   Avg. write : $(averageio "$iow1" "$iow2" "$iow3") MB/s" | tee -a $log
	echo "   Avg. read  : $(averageio "$ior1" "$ior2" "$ior3") MB/s" | tee -a $log
	rm "$RAMDISK_TEMP_DIR"/zero
	umount "$RAMDISK_TEMP_DIR"
	rm -rf "$RAMDISK_TEMP_DIR"
	echo "" | tee -a $log
	
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
	if [[ $writemb_size == "1024MB" ]]; then
		writemb_size="1.0GB"
	fi

	if [[ $writemb != "1" ]]; then
		echostyle "Disk Speed:"
		echo -n "   1st run    : " | tee -a $log
		io1=$( write_test "$writemb" ) # Added quotes
		echo -e "$io1" | tee -a $log
		echo -n "   2nd run    : " | tee -a $log
		io2=$( write_test "$writemb" ) # Added quotes
		echo -e "$io2" | tee -a $log
		echo -n "   3rd run    : " | tee -a $log
		io3=$( write_test "$writemb" ) # Added quotes
		echo -e "$io3" | tee -a $log
		ioraw1=$( echo "$io1" | awk 'NR==1 {print $1}' ) # Added quotes
		[ "`echo "$io1" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
		ioraw2=$( echo "$io2" | awk 'NR==1 {print $1}' ) # Added quotes
		[ "`echo "$io2" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
		ioraw3=$( echo "$io3" | awk 'NR==1 {print $1}' ) # Added quotes
		[ "`echo "$io3" | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
		ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
		ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
		echo -e "   -----------------------" | tee -a $log
		echo -e "   Average    : $ioavg MB/s" | tee -a $log
	else
		echo -e " Not enough space!"
	fi
}

print_end_time() {
	echo "" | tee -a $log
	end=$(date +%s) 
	time=$(( $end - $start ))
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
	echo " Timestamp   : $utc_time GMT" | tee -a $log
	#echo " Finished!"
	echo " Saved in    : $log"
	echo "" | tee -a $log
}

print_intro() {
	printf "%-75s\n" "-" | sed 's/\s/-/g'
	printf ' Region: %s  https://bench.laset.com '$bench_v' '$bench_d' \n' "$region_name" | tee -a $log # Added quotes
	printf " Usage : curl -sL bench.laset.com | bash -s -- -%s\n" "$region_name" | tee -a $log # Added quotes
}

sharetest() {
	echo " Share results:"
	echo " - $result_speed" | tee -a $log
	log_preupload
	case $1 in
	#'ubuntu')
	#	share_link=$( curl -v --data-urlencode "content@$log_up" -d "poster=speedtest.sh" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 | \
	#		grep "Location" | awk '{print "https://paste.ubuntu.com"$3}' );;
	#'haste' )
	#	share_link=$( curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}' );;
	#'clbin' )
	#	share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
		#sprunge_link=$(curl -sF 'sprunge=<-' https://sprunge.us < $log);;
	esac

	# Replace "http://" with "https://"
	#share_link=$(echo "$sprunge_link" | sed 's/http:/https:/')

	# print result info
	echo " - $GEEKBENCH_URL" | tee -a $log
	#echo " - $share_link"
	echo ""
	rm -f "$log_up" # Added quotes

}

log_preupload() {
	log_up="$HOME/speedtest_upload.log"
	true > "$log_up" # Added quotes
	$(cat speedtest.log 2>&1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > "$log_up") # Added quotes
}

get_ip_whois_org_name(){
	#ip=$(curl -s ip.sb)
	result=$(curl -s https://rest.db.ripe.net/search.json?query-string=$(curl -s ip.sb))
	#org_name=$(echo $result | jq '.objects.object.[1].attributes.attribute.[1].value' | sed 's/\"//g')
	org_name=$(echo "$result" | jq '.objects.object[1].attributes.attribute[1]' | sed 's/\"//g') # Added quotes
    echo "$org_name"; # Added quotes
}