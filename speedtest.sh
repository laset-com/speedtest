#!/usr/bin/env bash

about() {
	echo ""
	echo " ========================================================= "
	echo " \                      Bench.Monster                    / "
	echo " \         https://bench.monster/speedtest.html          / "
	echo " \       Basic system info, I/O test and speedtest       / "
	echo " \                  v1.1.7 (27 Sep 2019)                 / "
	echo " ========================================================= "
	echo ""
}

cancel() {
	echo ""
	next;
	echo " Abort ..."
	echo " Cleanup ..."
	cleanup;
	echo " Done"
	exit
}

trap cancel SIGINT

benchinit() {
	# check release
	if [ -f /etc/redhat-release ]; then
	    release="centos"
	elif cat /etc/issue | grep -Eqi "debian"; then
	    release="debian"
	elif cat /etc/issue | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	elif cat /proc/version | grep -Eqi "debian"; then
	    release="debian"
	elif cat /proc/version | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	fi

	# check root
	[[ $EUID -ne 0 ]] && echo -e "Error: This script must be run as root!" && exit 1

	# check python
	if  [ ! -e '/usr/bin/python' ]; then
	        #echo -e
	        #read -p "Error: python is not install. You must be install python command at first.\nDo you want to install? [y/n]" is_install
	        #if [[ ${is_install} == "y" || ${is_install} == "Y" ]]; then
	        echo " Installing Python ..."
	            if [ "${release}" == "centos" ]; then
	            		yum update > /dev/null 2>&1
	                    yum -y install python > /dev/null 2>&1
	                else
	                	apt-get update > /dev/null 2>&1
	                    apt-get -y install python > /dev/null 2>&1
	                fi
	        #else
	        #    exit
	        #fi
	        
	fi

	# check curl
	if  [ ! -e '/usr/bin/curl' ]; then
	    #echo -e
	    #read -p "Error: curl is not install. You must be install curl command at first.\nDo you want to install? [y/n]" is_install
	    #if [[ ${is_install} == "y" || ${is_install} == "Y" ]]; then
	        echo " Installing Curl ..."
	            if [ "${release}" == "centos" ]; then
	                yum update > /dev/null 2>&1
	                yum -y install curl > /dev/null 2>&1
	            else
	                apt-get update > /dev/null 2>&1
	                apt-get -y install curl > /dev/null 2>&1
	            fi
	    #else
	    #    exit
	    #fi
	fi

	# check wget
	if  [ ! -e '/usr/bin/wget' ]; then
	    #echo -e
	    #read -p "Error: wget is not install. You must be install wget command at first.\nDo you want to install? [y/n]" is_install
	    #if [[ ${is_install} == "y" || ${is_install} == "Y" ]]; then
	        echo " Installing Wget ..."
	            if [ "${release}" == "centos" ]; then
	                yum update > /dev/null 2>&1
	                yum -y install wget > /dev/null 2>&1
	            else
	                apt-get update > /dev/null 2>&1
	                apt-get -y install wget > /dev/null 2>&1
	            fi
	    #else
	    #    exit
	    #fi
	fi

	# install virt-what
	#if  [ ! -e '/usr/sbin/virt-what' ]; then
	#	echo "Installing Virt-what ..."
	#    if [ "${release}" == "centos" ]; then
	#    	yum update > /dev/null 2>&1
	#        yum -y install virt-what > /dev/null 2>&1
	#    else
	#    	apt-get update > /dev/null 2>&1
	#        apt-get -y install virt-what > /dev/null 2>&1
	#    fi      
	#fi

	# install jq
	#if  [ ! -e '/usr/bin/jq' ]; then
	# 	echo " Installing Jq ..."
    #		if [ "${release}" == "centos" ]; then
	#	    yum update > /dev/null 2>&1
	#	    yum -y install jq > /dev/null 2>&1
	#	else
	#	    apt-get update > /dev/null 2>&1
	#	    apt-get -y install jq > /dev/null 2>&1
	#	fi      
	#fi

	# install speedtest-cli
	if  [ ! -e 'speedtest.py' ]; then
		echo " Installing Speedtest-cli ..."
		wget --no-check-certificate https://raw.github.com/sivel/speedtest-cli/master/speedtest.py > /dev/null 2>&1
	fi
	chmod a+rx speedtest.py


	# install tools.py
	if  [ ! -e 'tools.py' ]; then
		echo " Installing tools.py ..."
		wget --no-check-certificate https://raw.githubusercontent.com/oooldking/script/master/tools.py > /dev/null 2>&1
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

speed_test(){
	if [[ $1 == '' ]]; then
		temp=$(python speedtest.py --share 2>&1)
		is_down=$(echo "$temp" | grep 'Download')
		result_speed=$(echo "$temp" | awk -F ' ' '/results/{print $3}')
		if [[ ${is_down} ]]; then
	        local REDownload=$(echo "$temp" | awk -F ':' '/Download/{print $2}')
	        local reupload=$(echo "$temp" | awk -F ':' '/Upload/{print $2}')
	        local relatency=$(echo "$temp" | awk -F ':' '/Hosted/{print $2}')

	        temp=$(echo "$relatency" | awk -F '.' '{print $1}')
        	if [[ ${temp} -gt 50 ]]; then
            	relatency=" (*)"${relatency}
        	fi
	        local nodeName=$2

	        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	        	printf "%-17s%-18s%-20s%-12s\n" " ${nodeName}" "${reupload}" "${REDownload}" "${relatency}" | tee -a $log
	        fi
		else
	        local cerror="ERROR"
		fi
	else
		temp=$(python speedtest.py --server $1 --share 2>&1)
		is_down=$(echo "$temp" | grep 'Download') 
		if [[ ${is_down} ]]; then
	        local REDownload=$(echo "$temp" | awk -F ':' '/Download/{print $2}')
	        local reupload=$(echo "$temp" | awk -F ':' '/Upload/{print $2}')
	        local relatency=$(echo "$temp" | awk -F ':' '/Hosted/{print $2}')
	        local relatency=$(pingtest $3)
	        #temp=$(echo "$relatency" | awk -F '.' '{print $1}')
        	#if [[ ${temp} -gt 1000 ]]; then
            	#relatency=" - "
        	#fi
	        local nodeName=$2

	        temp=$(echo "${REDownload}" | awk -F ' ' '{print $1}')
	        if [[ $(awk -v num1=${temp} -v num2=0 'BEGIN{print(num1>num2)?"1":"0"}') -eq 1 ]]; then
	        	printf "%-17s%-18s%-20s%-12s\n" " ${nodeName}" "${reupload}" "${REDownload}" "${relatency}" | tee -a $log
			fi
		else
	        local cerror="ERROR"
		fi
	fi
}

print_speedtest() {
	printf "%-26s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency" | tee -a $log
        speed_test '' 'Speedtest.net           '
	speed_test '14887' 'Ukraine, Lviv (UARNet)  ' 'http://speedtest.uar.net'
	speed_test '2445' 'Ukraine, Lviv (KOMiTEX) ' 'http://speedtest.komitex.net'
	speed_test '12786' 'Ukraine, Lviv (ASTRA)   ' 'http://speedtest.astra.in.ua'
	speed_test '17398' 'Ukraine, Lviv (Kopiyka) ' 'http://speedtest.kopiyka.org'
	speed_test '6225' 'Ukraine, Lviv (ZNet)    ' 'http://178.212.102.70'
	speed_test '1204' 'Ukraine, Lviv (Network) ' 'http://speedtest.network.lviv.ua'
	speed_test '21900' 'Ukraine, Lviv (LimNet)  ' 'http://speedtest.limnet.com.ua'
	 
	rm -rf speedtest.py
}

print_speedtest_ukraine() {
	printf "%-26s%-18s%-20s%-12s\n" " Node Name" "Upload Speed" "Download Speed" "Latency" | tee -a $log
        speed_test '' 'Speedtest.net           '
	speed_test '14887' 'Ukraine, Lviv (UARNet)  ' 'http://speedtest.uar.net'
	speed_test '2445' 'Ukraine, Lviv (KOMiTEX) ' 'http://speedtest.komitex.net'
	speed_test '12786' 'Ukraine, Lviv (ASTRA)   ' 'http://speedtest.astra.in.ua'
	speed_test '17398' 'Ukraine, Lviv (Kopiyka) ' 'http://speedtest.kopiyka.org'
	speed_test '6225' 'Ukraine, Lviv (ZNet)    ' 'http://178.212.102.70'
	speed_test '1204' 'Ukraine, Lviv (Network) ' 'http://speedtest.network.lviv.ua'
	speed_test '21900' 'Ukraine, Lviv (LimNet)  ' 'http://speedtest.limnet.com.ua'
	 
	rm -rf speedtest.py
}

io_test() {
    (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

power_time() {

	result=$(smartctl -a $(result=$(cat /proc/mounts) && echo $(echo "$result" | awk '/data=ordered/{print $1}') | awk '{print $1}') 2>&1) && power_time=$(echo "$result" | awk '/Power_On/{print $10}') && echo "$power_time"
}

install_smart() {
	# install smartctl
	if  [ ! -e '/usr/sbin/smartctl' ]; then
		echo "Installing Smartctl ..."
	    if [ "${release}" == "centos" ]; then
	    	yum update > /dev/null 2>&1
	        yum -y install smartmontools > /dev/null 2>&1
	    else
	    	apt-get update > /dev/null 2>&1
	        apt-get -y install smartmontools > /dev/null 2>&1
	    fi      
	fi
}

ip_info(){
	# use jq tool
	result=$(curl -s 'http://ip-api.com/json')
	country=$(echo $result | jq '.country' | sed 's/\"//g')
	city=$(echo $result | jq '.city' | sed 's/\"//g')
	isp=$(echo $result | jq '.isp' | sed 's/\"//g')
	as_tmp=$(echo $result | jq '.as' | sed 's/\"//g')
	asn=$(echo $as_tmp | awk -F ' ' '{print $1}')
	org=$(echo $result | jq '.org' | sed 's/\"//g')
	countryCode=$(echo $result | jq '.countryCode' | sed 's/\"//g')
	region=$(echo $result | jq '.regionName' | sed 's/\"//g')
	if [ -z "$city" ]; then
		city=${region}
	fi

	echo -e " ASN & ISP            : $asn, $isp" | tee -a $log
	echo -e " Organization         : $org" | tee -a $log
	echo -e " Location             : $city, $country / $countryCode" | tee -a $log
	echo -e " Region               : $region" | tee -a $log
}

ip_info2(){
	# no jq
	country=$(curl -s https://ipapi.co/country_name/)
	city=$(curl -s https://ipapi.co/city/)
	asn=$(curl -s https://ipapi.co/asn/)
	org=$(curl -s https://ipapi.co/org/)
	countryCode=$(curl -s https://ipapi.co/country/)
	region=$(curl -s https://ipapi.co/region/)

	echo -e " ASN & ISP            : $asn" | tee -a $log
	echo -e " Organization         : $org" | tee -a $log
	echo -e " Location             : $city, $country / $countryCode" | tee -a $log
	echo -e " Region               : $region" | tee -a $log
}

ip_info3(){
	# use python tool
	country=$(python ip_info.py country)
	city=$(python ip_info.py city)
	isp=$(python ip_info.py isp)
	as_tmp=$(python ip_info.py as)
	asn=$(echo $as_tmp | awk -F ' ' '{print $1}')
	org=$(python ip_info.py org)
	countryCode=$(python ip_info.py countryCode)
	region=$(python ip_info.py regionName)

	echo -e " ASN & ISP            : $asn, $isp" | tee -a $log
	echo -e " Organization         : $org" | tee -a $log
	echo -e " Location             : $city, $country / $countryCode" | tee -a $log
	echo -e " Region               : $region" | tee -a $log

	rm -rf ip_info.py
}

ip_info4(){
	ip_date=$(curl -4 -s http://api.ip.la/en?json)
	echo $ip_date > ip_json.json
	isp=$(python tools.py geoip isp)
	as_tmp=$(python tools.py geoip as)
	asn=$(echo $as_tmp | awk -F ' ' '{print $1}')
	org=$(python tools.py geoip org)
	if [ -z "ip_date" ]; then
		echo $ip_date
		echo "hala"
		country=$(python tools.py ipip country_name)
		city=$(python tools.py ipip city)
		countryCode=$(python tools.py ipip country_code)
		region=$(python tools.py ipip province)
	else
		country=$(python tools.py geoip country)
		city=$(python tools.py geoip city)
		countryCode=$(python tools.py geoip countryCode)
		region=$(python tools.py geoip regionName)	
	fi
	if [ -z "$city" ]; then
		city=${region}
	fi

	echo -e " ASN & ISP            : $asn, $isp" | tee -a $log
	echo -e " Organization         : $org" | tee -a $log
	echo -e " Location             : $city, $country / $countryCode" | tee -a $log
	echo -e " Region               : $region" | tee -a $log

	rm -rf tools.py
	rm -rf ip_json.json
}

virt_check(){
	if hash ifconfig 2>/dev/null; then
		eth=$(ifconfig)
	fi

	virtualx=$(dmesg) 2>/dev/null
	
	if grep docker /proc/1/cgroup -qa; then
	    virtual="Docker"
	elif grep lxc /proc/1/cgroup -qa; then
		virtual="Lxc"
	elif grep -qa container=lxc /proc/1/environ; then
		virtual="Lxc"
	elif [[ -f /proc/user_beancounters ]]; then
		virtual="OpenVZ"
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
	else
		virtual="Dedicated"
	fi
}

power_time_check(){
	echo -ne " Power time of disk   : "
	install_smart
	ptime=$(power_time)
	echo -e "$ptime Hours"
}

freedisk() {
	# check free space
	#spacename=$( df -m . | awk 'NR==2 {print $1}' )
	#spacenamelength=$(echo ${spacename} | awk '{print length($0)}')
	#if [[ $spacenamelength -gt 20 ]]; then
   	#	freespace=$( df -m . | awk 'NR==3 {print $3}' )
	#else
	#	freespace=$( df -m . | awk 'NR==2 {print $4}' )
	#fi
	freespace=$( df -m . | awk 'NR==2 {print $4}' )
	if [[ $freespace == "" ]]; then
		$freespace=$( df -m . | awk 'NR==3 {print $3}' )
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

print_io() {
	if [[ $1 == "fast" ]]; then
		writemb=$((128*2))
	else
		writemb=$(freedisk)
	fi
	
	writemb_size="$(( writemb / 2 ))MB"
	if [[ $writemb_size == "1024MB" ]]; then
		writemb_size="1.0GB"
	fi

	if [[ $writemb != "1" ]]; then
		echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
		io1=$( io_test $writemb )
		echo -e "$io1" | tee -a $log
		echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
		io2=$( io_test $writemb )
		echo -e "$io2" | tee -a $log
		echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
		io3=$( io_test $writemb )
		echo -e "$io3" | tee -a $log
		ioraw1=$( echo $io1 | awk 'NR==1 {print $1}' )
		[ "`echo $io1 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
		ioraw2=$( echo $io2 | awk 'NR==1 {print $1}' )
		[ "`echo $io2 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
		ioraw3=$( echo $io3 | awk 'NR==1 {print $1}' )
		[ "`echo $io3 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
		ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
		ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
		echo -e " Average I/O Speed    : $ioavg MB/s" | tee -a $log
	else
		echo -e " Not enough space!"
	fi
}

print_system_info() {
	echo -e " CPU Model            : $cname" | tee -a $log
	echo -e " CPU Cores            : $cores Cores @ $freq MHz $arch $corescache Cache" | tee -a $log
	echo -e " OS                   : $opsy ($lbit Bit)" | tee -a $log
	echo -e " Kernel               : $virtual / $kern" | tee -a $log
	echo -e " Total Space          : $disk_used_size GB / $disk_total_size GB " | tee -a $log
	echo -e " Total RAM            : $uram MB / $tram MB ($bram MB Buff)" | tee -a $log
	echo -e " Total SWAP           : $uswap MB / $swap MB" | tee -a $log
	echo -e " Uptime               : $up" | tee -a $log
	echo -e " Load Average         : $load" | tee -a $log
	#echo -e " TCP CC               : $tcpctrl" | tee -a $log
}

print_end_time() {
	end=$(date +%s) 
	time=$(( $end - $start ))
	if [[ $time -gt 60 ]]; then
		min=$(expr $time / 60)
		sec=$(expr $time % 60)
		echo -ne " Finished in  : ${min} min ${sec} sec" | tee -a $log
	else
		echo -ne " Finished in  : ${time} sec" | tee -a $log
	fi
	#echo -ne "\n Current time : "
	#echo $(date +%Y-%m-%d" "%H:%M:%S)
	printf '\n' | tee -a $log
	utc_time=$(date -u '+%F %T')
	echo " Timestamp    : $utc_time UTC" | tee -a $log
	#echo " Finished!"
	echo " Results      : $log"
}

get_system_info() {
	cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	corescache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	tram=$( free -m | awk '/Mem/ {print $2}' )
	uram=$( free -m | awk '/Mem/ {print $3}' )
	bram=$( free -m | awk '/Mem/ {print $6}' )
	swap=$( free -m | awk '/Swap/ {print $2}' )
	uswap=$( free -m | awk '/Swap/ {print $3}' )
	up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d hour %d min\n",a,b,c)}' /proc/uptime )
	load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
	opsy=$( get_opsy )
	arch=$( uname -m )
	lbit=$( getconf LONG_BIT )
	kern=$( uname -r )
	#ipv6=$( wget -qO- -t1 -T2 ipv6.icanhazip.com )
	disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' ))
	disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' ))
	disk_total_size=$( calc_disk ${disk_size1[@]} )
	disk_used_size=$( calc_disk ${disk_size2[@]} )
	#tcp congestion control
	#tcpctrl=$( sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )

	#tmp=$(python tools.py disk 0)
	#disk_total_size=$(echo $tmp | sed s/G//)
	#tmp=$(python tools.py disk 1)
	#disk_used_size=$(echo $tmp | sed s/G//)

	virt_check
}

print_intro() {
	printf ' Speedtest Monster v.1.1.7 \n' | tee -a $log
	printf " Region: %s  https://bench.monster/speedtest.html\n" $region_name | tee -a $log
	printf " curl -LsO bench.monster/speedtest.sh; sh speedtest.sh -%s\n" $region_name | tee -a $log
}

sharetest() {
	echo " Share result:" | tee -a $log
	echo " · $result_speed" | tee -a $log
	log_preupload
	case $1 in
	'ubuntu')
		share_link=$( curl -v --data-urlencode "content@$log_up" -d "poster=speedtest.sh" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 | \
			grep "Location" | awk '{print $3}' );;
	'haste' )
		share_link=$( curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}' );;
	'clbin' )
		share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
	esac

	# print result info
	echo " · $share_link" | tee -a $log
	next
	echo ""
	rm -f $log_up

}

log_preupload() {
	log_up="$HOME/speedtest_upload.log"
	true > $log_up
	$(cat speedtest.log 2>&1 | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > $log_up)
}

get_ip_whois_org_name(){
	#ip=$(curl -s ip.sb)
	result=$(curl -s https://rest.db.ripe.net/search.json?query-string=$(curl -s ip.sb))
	#org_name=$(echo $result | jq '.objects.object.[1].attributes.attribute.[1].value' | sed 's/\"//g')
	org_name=$(echo $result | jq '.objects.object[1].attributes.attribute[1]' | sed 's/\"//g')
    echo $org_name;
}

pingtest() {
	local ping_link=$( echo ${1#*//} | cut -d"/" -f1 )
	local ping_ms=$( ping -w 1 -c 1 -q $ping_link | grep 'rtt' | cut -d"/" -f5 )

	# get download speed and print
	if [[ $ping_ms == "" ]]; then
		printf "ping error!"  | tee -a $log
	else
		printf "%3i.%s ms" "${ping_ms%.*}" "${ping_ms#*.}"  | tee -a $log
	fi
}

cleanup() {
	rm -f test_file_*;
	rm -f speedtest.py;
	rm -f tools.py;
	rm -f ip_json.json
}

bench_all(){
	mode_name="Standard"
	print_intro;
	next;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	print_io;
	next;
	print_speedtest;
	next;
	print_end_time;
	next;
	cleanup;
	sharetest clbin;
}

ukraine_bench(){
	region_name="Ukraine"
	print_intro;
	next;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	print_io;
	next;
	print_speedtest_ukraine;
	next;
	print_end_time;
	next;
	cleanup;
}




log="$HOME/speedtest.log"
true > $log

case $1 in
	'info'|'-i'|'--i'|'-info'|'--info' )
		about;sleep 3;next;get_system_info;print_system_info;next;;
    'version'|'-v'|'--v'|'-version'|'--version')
		next;about;next;;
   	'io'|'-io'|'--io'|'-drivespeed'|'--drivespeed' )
		next;print_io;next;;
	'speed'|'-speed'|'--speed'|'-speedtest'|'--speedtest'|'-speedcheck'|'--speedcheck' )
		about;benchinit;next;print_speedtest;next;cleanup;;
	'ip'|'-ip'|'--ip'|'geoip'|'-geoip'|'--geoip' )
		about;benchinit;next;ip_info4;next;cleanup;;
	'bench'|'-a'|'--a'|'-all'|'--all'|'-bench'|'--bench' )
		bench_all;;
	'about'|'-about'|'--about' )
		about;;
	'ukraine'|'-ukraine'|'--ukraine'|'-ua'|'--ua'|'-Ukraine'|'--Ukraine' )
		ukraine_bench;;
	'share'|'-s'|'--s'|'-share'|'--share' )
		bench_all;
		is_share="share"
		if [[ $2 == "" ]]; then
			sharetest ubuntu;
		else
			sharetest $2;
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
				sharetest ubuntu;
			else
				sharetest $3;
			fi
			;;
	esac
fi
