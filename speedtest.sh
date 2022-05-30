#!/usr/bin/env bash

about() {
	echo ""
	echo " ========================================================= "
	echo " \            Speedtest https://bench.monster            / "
	echo " \    System info, Geekbench, I/O test and speedtest     / "
	echo " \                  v1.5.10   2022-05-30                 / "
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

benchram="$HOME/tmpbenchram"
NULL="/dev/null"

# determine architecture of host
ARCH=$(uname -m)
if [[ $ARCH = *x86_64* ]]; then
	# host is running a 64-bit kernel
	ARCH="x64"
elif [[ $ARCH = *i?86* ]]; then
	# host is running a 32-bit kernel
	ARCH="x86"
else
	# host is running a non-supported kernel
	echo -e "Architecture not supported."
	exit 1
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

	# check OS
	#if [ "${release}" == "centos" ]; then
	#                echo "Checking OS ... [ok]"
	#else
	#                echo "Error: This script must be run on CentOS!"
	#		exit 1
	#fi
	#echo -ne "\e[1A"; echo -ne "\e[0K\r"
	
	# check root
	[[ $EUID -ne 0 ]] && echo -e "Error: This script must be run as root!" && exit 1
	

	# check python
	if  [ ! -e '/usr/bin/python' ]; then
	        echo " Installing Python2 ..."
	            if [ "${release}" == "centos" ]; then
	                    yum -y install python2 > /dev/null 2>&1
			    alternatives --set python /usr/bin/python2 > /dev/null 2>&1
	                else
	                    apt-get -y install python > /dev/null 2>&1
	                fi
	        echo -ne "\e[1A"; echo -ne "\e[0K\r" 
	fi

	# check curl
	if  [ ! -e '/usr/bin/curl' ]; then
	        echo " Installing Curl ..."
	            if [ "${release}" == "centos" ]; then
	                yum -y install curl > /dev/null 2>&1
	            else
	                apt-get -y install curl > /dev/null 2>&1
	            fi
		echo -ne "\e[1A"; echo -ne "\e[0K\r"
	fi

	# check wget
	if  [ ! -e '/usr/bin/wget' ]; then
	        echo " Installing Wget ..."
	            if [ "${release}" == "centos" ]; then
	                yum -y install wget > /dev/null 2>&1
	            else
	                apt-get -y install wget > /dev/null 2>&1
	            fi
		echo -ne "\e[1A"; echo -ne "\e[0K\r"
	fi
	
	# check bzip2
	if  [ ! -e '/usr/bin/bzip2' ]; then
	        echo " Installing bzip2 ..."
	            if [ "${release}" == "centos" ]; then
	                yum -y install bzip2 > /dev/null 2>&1
	            else
	                apt-get -y install bzip2 > /dev/null 2>&1
	            fi
		echo -ne "\e[1A"; echo -ne "\e[0K\r"
	fi
	
	# check tar
	if  [ ! -e '/usr/bin/tar' ]; then
	        echo " Installing tar ..."
	            if [ "${release}" == "centos" ]; then
	                yum -y install tar > /dev/null 2>&1
	            else
	                apt-get -y install tar > /dev/null 2>&1
	            fi
		echo -ne "\e[1A"; echo -ne "\e[0K\r"
	fi

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
		temp=$(python speedtest.py --share 2>&1)
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
		temp=$(python speedtest.py --server $1 --share 2>&1)
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
	speed_test '30514' 'USA, New York (Optimum)       ' 'http://speedgauge2.optonline.net'
	speed_test '17384' 'USA, Chicago (Windstream)     ' 'http://chicago02.speedtest.windstream.net'
	speed_test '14238' 'USA, Dallas (Frontier)        ' 'http://dallas.tx.speedtest.frontier.com'
	speed_test '15781' 'USA, Miami (Sprint)           ' 'http://ookla1.miaufl.sprintadp.net'
	speed_test '18401' 'USA, Los Angeles (Windstream) ' 'http://la02.speedtest.windstream.net'
	speed_test '26922' 'UK, London (toob Ltd)         ' 'http://speedtest.ukbroadband.com'
	speed_test '27852' 'France, Lyon (SFR)            ' 'http://cor2.speedtest.mire.sfr.net'
	speed_test '20507' 'Germany, Berlin (DNS:NET)     ' 'http://speedtest01.dns-net.de'
	speed_test '21378' 'Spain, Madrid (MasMovil)      ' 'http://speedtest-mad.masmovil.com'
	speed_test '395' 'Italy, Rome (Unidata)         ' 'http://speedtest2.unidata.it'
	speed_test '10637' 'India, Mumbai (OneBroadband)  ' 'http://in2net.in2cable.com'
	speed_test '7556' 'Singapore (FirstMedia)        ' 'http://sg-speedtest.link.net.id'
	speed_test '7139' 'Japan, Tsukuba (SoftEther)    ' 'http://speedtest2.softether.co.jp'
	speed_test '1267' 'Australia, Sydney (Optus)     ' 'http://s1.speedtest.syd.optusnet.com.au'
	speed_test '6591' 'RSA, Randburg (Cool Ideas)    ' 'http://sp2.cisp.co.za'
	speed_test '11488' 'Brazil, Sao Paulo (Criare)    ' 'http://ookla.spcom.net.br'
	 
	rm -rf speedtest.py
}

print_speedtest_usa() {
	echo "" | tee -a $log
	echostyle "## USA Speedtest.net"
	echo "" | tee -a $log
	printf "%-33s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                         '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '30514' 'USA, New York (Optimum)        ' 'http://speedgauge2.optonline.net'
	speed_test '13429' 'USA, Boston (Starry, Inc.)     ' 'http://speedtest-server.starry.com'
	speed_test '15790' 'USA, Washington, DC (Sprint)   ' 'http://ookla1.washdc.sprintadp.net'
	speed_test '27833' 'USA, Charlotte, NC (Windstream)' 'http://charlotte02.speedtest.windstream.net'
	speed_test '16611' 'USA, Atlanta (Cox)             ' 'http://speedtest.rd.at.cox.net'
	speed_test '15781' 'USA, Miami (Sprint)            ' 'http://ookla1.miaufl.sprintadp.net'
	speed_test '15779' 'USA, Nashville (Sprint)        ' 'http://ookla1.nsvltn.sprintadp.net'
	speed_test '9560' 'USA, Indianapolis (Metronet)   ' 'http://speedtest2.iplwin75.metronetinc.com'
	speed_test '10138' 'USA, Cleveland (CenturyLink)   ' 'http://cleveland.speedtest.centurylink.net'
	speed_test '17384' 'USA, Chicago (Windstream)      ' 'http://chicago02.speedtest.windstream.net'
	speed_test '4557' 'USA, St. Louis (Elite Fiber)   ' 'http://speed.elitesystemsllc.com'
	speed_test '2917' 'USA, Minneapolis (US Internet) ' 'http://speedtest.usiwireless.com'
	speed_test '17709' 'USA, Kansas City (UPNfiber)    ' 'http://speedtest.upnfiber.com'
	speed_test '17751' 'USA, Oklahoma City (OneNet)    ' 'http://okc-speedtest.onenet.net'
	speed_test '17386' 'USA, Dallas (Windstream)       ' 'http://dallas02.speedtest.windstream.net'
	speed_test '11209' 'USA, San Antonio, TX (Sprint)  ' 'http://ookla1.snantx.sprintadp.net'
	speed_test '19124' 'USA, Denver (Vistabeam)        ' 'http://ookla-denver.vistabeam.com'
	speed_test '16869' 'USA, Albuquerque (Plateau Tel) ' 'http://speedtest4.plateautel.net'
	speed_test '16613' 'USA, Phoenix (Cox)             ' 'http://speedtest.rd.ph.cox.net'
	speed_test '2206' 'USA, Salt Lake City (UTOPIA)   ' 'http://speedtest2.utopiafiber.net'
	speed_test '7878' 'USA, Helena, MT (The Fusion)   ' 'http://helenast2.northcentraltower.com'
	speed_test '16622' 'USA, Las Vegas (Cox)           ' 'http://speedtest.rd.lv.cox.net'
	speed_test '18271' 'USA, Seattle (Bluespan)        ' 'http://seattle.speedtest.bluespanwireless.com'
	speed_test '17587' 'USA, San Francisco (Wiline)    ' 'http://sfosfookla.wiline.com'
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
	speed_test '10637' 'India, Mumbai (OneBroadband)   ' 'http://in2net.in2cable.com'
	speed_test '13919' 'India, Bengaluru (I-ON)        ' 'http://speedtestb.dvois.com'
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
	speed_test '26922' 'UK, London (toob Ltd)           ' 'http://speedtest.ukbroadband.com'
	speed_test '13218' 'Netherlands, Amsterdam (XS4ALL) ' 'http://speedtest.xs4all.nl'
	speed_test '20507' 'Germany, Berlin (DNS:NET)       ' 'http://speedtest01.dns-net.de'
	speed_test '27345' 'Germany, Munich (InterNetX)     ' 'http://speedtest.internetx.de'
	speed_test '8751' 'Denmark, Copenhagen (Fiberby)   ' 'http://speedtest.internetx.de'
	speed_test '26852' 'Sweden, Stockholm (SUNET)       ' 'http://fd.sunet.se'
	speed_test '8018' 'Norway, Oslo (NextGenTel)       ' 'http://sp2.nextgentel.no'
	speed_test '27852' 'France, Lyon (SFR)              ' 'http://cor2.speedtest.mire.sfr.net'
	speed_test '21378' 'Spain, Madrid (MasMovil)        ' 'http://speedtest-mad.masmovil.com'
	speed_test '395' 'Italy, Rome (Unidata)           ' 'http://speedtest2.unidata.it'
	speed_test '21975' 'Czechia, Prague (Nordic Telecom)' 'http://ookla.nordictelecom.cz'
	speed_test '12390' 'Austria, Vienna (A1)            ' 'http://speedtest.a1.net'
	speed_test '7103' 'Poland, Warsaw (ISP Emitel)     ' 'http://speedtest.emitel.pl'
	speed_test '30813' 'Ukraine, Kyiv (KyivStar)        ' 'http://srv01-okl-kv.kyivstar.ua'
	speed_test '5834' 'Latvia, Riga (Bite)             ' 'http://speedtest2.bite.lv'
	speed_test '7609' 'Romania, Bucharest (DOTRO Tel)  ' 'http://sp1.dotrotelecom.ro'
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
	speed_test '10637' 'India, Mumbai (OneBroadband)    ' 'http://in2net.in2cable.com'
	speed_test '13919' 'India, Bengaluru (I-ON)         ' 'http://speedtestb.dvois.com'
	speed_test '1131' 'Sri Lanka, Colombo (Telecom PLC)' 'http://speedtest2.sltnet.lk'
	speed_test '4774' 'Pakistan, Islamabad (Telenor)   ' 'http://speedtest1.telenor.com.pk'
	speed_test '5792' 'Mongolia, Ulaanbaatar (Mobicom) ' 'http://coverage.mobicom.mn'
	speed_test '7147' 'Bangladesh, Dhaka (Skytel)      ' 'http://sp1.cosmocom.net'
	speed_test '14901' 'Bhutan, Thimphu (Bhutan Telecom)' 'http://speedtest.bt.bt'
	speed_test '20882' 'Myanmar, Mandalay (Ooredoo)     ' 'http://speedtest.ooredoo.com.mm'
	speed_test '26845' 'Laos, Vientaine (Mangkone)      ' 'http://speedtest.mangkone.com'
	speed_test '13871' 'Thailand, Bangkok (CAT Telecom) ' 'http://catspeedtest.net'
	speed_test '12545' 'Cambodia, Phnom Penh (Smart)    ' 'http://speedtest.smart.com.kh'
	speed_test '9903' 'Vietnam, Hanoi (Viettel)        ' 'http://speedtestkv1b.viettel.vn'
	speed_test '27261' 'Malaysia, Kuala Lumpur (Extreme)' 'http://kl-speedtest.ebb.my'
	speed_test '7556' 'Singapore (PT FirstMedia)       ' 'http://sg-speedtest.link.net.id'
	speed_test '17516' 'Indonesia, Jakarta (Desnet)     ' 'http://speedtest.desnet.id'
	speed_test '20273' 'Philippines, Manila (Globe Tel) ' 'http://119.92.238.90'
	speed_test '28912' 'Hong Kong (fdcservers)          ' 'http://lg-hkg.fdcservers.net'
	speed_test '13506' 'Taiwan, Taipei (TAIFO)          ' 'http://speedtest.taifo.com.tw'
	speed_test '7139' 'Japan, Tsukuba (SoftEther)      ' 'http://speedtest2.softether.co.jp'
	 
	rm -rf speedtest.py
}

print_speedtest_sa() {
	echo "" | tee -a $log
	echostyle "## South America Speedtest.net"
	echo "" | tee -a $log
	printf "%-38s%-17s%-16s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                              '
	printf "%-81s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '11488' 'Brazil, Sao Paulo (Criare)          ' 'http://ookla.spcom.net.br'
	speed_test '11435' 'Brazil, Fortaleza (Netonda)         ' 'http://speedtest.netonda.com.br'
	speed_test '18126' 'Brazil, Manaus (Claro)              ' 'http://spd7.claro.com.br'
	speed_test '11683' 'Colombia, Bogota (Level 3)          ' 'http://speedtest.globalcrossing.com.co'
	speed_test '1280' 'Ecuador, Quito (CNT EP.)            ' 'http://speedtest.puntonet.ec'
	speed_test '5272' 'Peru, Lima (Fiberluxperu)           ' 'http://medidor.fiberluxperu.com'
	speed_test '14099' 'Bolivia, La Paz (AXS)               ' 'http://speedtest.axsbolivia.com'
	speed_test '6776' 'Paraguay, Asuncion (TEISA)          ' 'http://sp1.teisa.com.py'
	speed_test '13065' 'Chile, Santiago (Netglobalis)       ' 'http://speedtest.netglobalis.net'
	speed_test '6825' 'Argentina, Buenos Aires (Telefonica)' 'http://speedtest2.gics.telefonica.com.ar'
	speed_test '10315' 'Argentina, Cordoba (Personal)       ' 'http://st1res.personal.com.ar'
	speed_test '1546' 'Uruguay, Montevideo (Antel)         ' 'http://speedtest.movistar.com.uy'
	 
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
	speed_test '1267' 'Australia, Sydney (Optus)     ' 'http://s1.speedtest.syd.optusnet.com.au'
	speed_test '2225' 'Australia, Melbourne (Telstra)' 'http://mel1.speedtest.telstra.net'
	speed_test '2604' 'Australia, Brisbane (Telstra) ' 'http://brs1.speedtest.telstra.net'
	speed_test '6359' 'Australia, Adelaide (AARNet)  ' 'http://sa-prka-speedtest.aarnet.net.au'
	speed_test '8976' 'Australia, Hobart (Optus)     ' 'http://speedtest.tas.optusnet.com.au'
	speed_test '6757' 'Australia, Darwin (AARNet)    ' 'http://nt-drwn-speedtest.aarnet.net.au'
	speed_test '2627' 'Australia, Perth (Telstra)    ' 'http://per1.speedtest.telstra.net'
	speed_test '2627' 'NZ, Auckland (MyRepublic)     ' 'http://per1.speedtest.telstra.net'
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
	speed_test '17398' 'Ukraine, Lviv (Kopiyka) ' 'http://speedtest.kopiyka.org'
	speed_test '29147' 'Ukraine, Lviv (LANNET)  ' 'http://speed.lannet.lviv.ua'
	speed_test '1204' 'Ukraine, Lviv (Network) ' 'http://speedtest.network.lviv.ua'
	speed_test '26293' 'Ukraine, Lviv (LinkCom) ' 'http://st.lc.lviv.ua'
	speed_test '33969' 'Ukraine, Lviv (ARKADA-X)' 'http://speedtest.arkada-x.com'
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
	speed_test '7120' 'Cyprus, Limassol (DragonNET)' 'http://speedtest1.dragonnet.eu'
	speed_test '2434' 'Israel, Haifa (013Netvision)' 'http://speed2.013.net'
	speed_test '1689' 'Egypt, Cairo (Vodafone)     ' 'http://speedtest.vodafone.com.eg'
	speed_test '12498' 'Lebanon, Tripoli (BItarNet) ' 'http://speedtest1.wavenet-lb.net'
	speed_test '4845' 'UAE, Dubai (du)             ' 'http://speedtest.orixcom.net'
	speed_test '14888' 'Qatar, Doha (Vodafone)      ' 'http://speedtest01.vodafone.com.qa'
	speed_test '12887' 'SA, Riyadh (GO)             ' 'http://speedtest.go.com.sa'
	speed_test '1912' 'Bahrain, Manama (Zain)      ' 'http://62.209.25.182'
	speed_test '13583' 'Iran, Tehran (Fanap Telecom)' 'http://speedtest.fanaptelecom.ir'
	 
	rm -rf speedtest.py
}

print_speedtest_china() {
	echo "" | tee -a $log
	echostyle "## China Speedtest.net"
	echo "" | tee -a $log
	printf "%-32s%-17s%-17s%-7s\n" " Location" "Upload" "Download" "Ping" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                      '
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '5505' 'BeiJing (Broadband Network)   ' 'http://bj3.unicomtest.com'
	speed_test '32291' 'HangZhou (China Mobile 5G)    ' 'http://changzhou.bestlink.com.cn'
	speed_test '6715' 'Ningbo (China Mobile 5G)      ' 'http://ltetest3.139site.com'
	 
	rm -rf speedtest.py
}

geekbench4() {
	if [[ $ARCH = *x86* ]]; then # 32-bit
	echo -e "\nGeekbench 5 cannot run on 32-bit architectures. Skipping the test"
	else
	echo "" | tee -a $log
	echo -e " Performing Geekbench v4 CPU Benchmark test. Please wait..."

	GEEKBENCH_PATH=$HOME/geekbench
	mkdir -p $GEEKBENCH_PATH
	curl -s http://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz  | tar xz --strip-components=1 -C $GEEKBENCH_PATH &>/dev/null
	GEEKBENCH_TEST=$($GEEKBENCH_PATH/geekbench4 2>/dev/null | grep "https://browser")
	GEEKBENCH_URL=$(echo -e $GEEKBENCH_TEST | head -1)
	GEEKBENCH_URL_CLAIM=$(echo $GEEKBENCH_URL | awk '{ print $2 }')
	GEEKBENCH_URL=$(echo $GEEKBENCH_URL | awk '{ print $1 }')
	sleep 20
	GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "span class='score'")
	GEEKBENCH_SCORES_SINGLE=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $3 }')
	GEEKBENCH_SCORES_MULTI=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $7 }')
	
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
	else
		grank="(THE BEAST)"
	fi
	
	echo -ne "\e[1A"; echo -ne "\033[0K\r"
	echostyle "## Geekbench v4 CPU Benchmark:"
	echo "" | tee -a $log
	echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a $log
	echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a $log
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

	GEEKBENCH_PATH=$HOME/geekbench
	mkdir -p $GEEKBENCH_PATH
	curl -s http://cdn.geekbench.com/Geekbench-5.4.4-Linux.tar.gz | tar xz --strip-components=1 -C $GEEKBENCH_PATH &>/dev/null
	GEEKBENCH_TEST=$($GEEKBENCH_PATH/geekbench5 2>/dev/null | grep "https://browser")
	GEEKBENCH_URL=$(echo -e $GEEKBENCH_TEST | head -1)
	GEEKBENCH_URL_CLAIM=$(echo $GEEKBENCH_URL | awk '{ print $2 }')
	GEEKBENCH_URL=$(echo $GEEKBENCH_URL | awk '{ print $1 }')
	sleep 20
	GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "div class='score'")
	GEEKBENCH_SCORES_SINGLE=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $3 }')
	GEEKBENCH_SCORES_MULTI=$(echo $GEEKBENCH_SCORES | awk -v FS="(<|>)" '{ print $7 }')
	
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
	else
		grank="(THE BEAST)"
	fi
	
	echo -ne "\e[1A"; echo -ne "\033[0K\r"
	echostyle "## Geekbench v5 CPU Benchmark:"
	echo "" | tee -a $log
	echo -e "  Single Core : $GEEKBENCH_SCORES_SINGLE  $grank" | tee -a $log
	echo -e "   Multi Core : $GEEKBENCH_SCORES_MULTI" | tee -a $log
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

	echo -e " ASN & ISP    : $asn, $isp" | tee -a $log
	echo -e " Organization : $org" | tee -a $log
	echo -e " Location     : $city, $country / $countryCode" | tee -a $log
	echo -e " Region       : $region" | tee -a $log
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

	echo -e " ASN & ISP    : $asn, $isp" | tee -a $log
	echo -e " Organization : $org" | tee -a $log
	echo -e " Location     : $city, $country / $countryCode" | tee -a $log
	echo -e " Region       : $region" | tee -a $log

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

	echo -e " ASN & ISP    : $asn, $isp" | tee -a $log
	echo -e " Organization : $org" | tee -a $log
	echo -e " Location     : $city, $country / $countryCode" | tee -a $log
	echo -e " Region       : $region" | tee -a $log

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

print_system_info() {
	echo -e " OS           : $opsy ($lbit Bit)" | tee -a $log
	echo -e " Virt/Kernel  : $virtual / $kern" | tee -a $log
	echo -e " CPU Model    : $cname" | tee -a $log
	echo -e " CPU Cores    : $cores @ $freq MHz $arch $corescache Cache" | tee -a $log
	echo -e " CPU Flags    : $cpu_aes & $cpu_virt" | tee -a $log
	echo -e " Load Average : $load" | tee -a $log
	echo -e " Total Space  : $hdd ($hddused ~$hddfree used)" | tee -a $log
	echo -e " Total RAM    : $tram MB ($uram MB + $bram MB Buff in use)" | tee -a $log
	echo -e " Total SWAP   : $swap MB ($uswap MB in use)" | tee -a $log
	echo -e " Uptime       : $up" | tee -a $log
	#echo -e " TCP CC       : $tcpctrl" | tee -a $log
	printf "%-75s\n" "-" | sed 's/\s/-/g' | tee -a $log
}

get_system_info() {
	cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
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

	#tmp=$(python tools.py disk 0)
	#disk_total_size=$(echo $tmp | sed s/G//)
	#tmp=$(python tools.py disk 1)
	#disk_used_size=$(echo $tmp | sed s/G//)

	virt_check
}

write_test() {
    (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

averageio() {
	ioraw1=$( echo $1 | awk 'NR==1 {print $1}' )
		[ "$(echo $1 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
	ioraw2=$( echo $2 | awk 'NR==1 {print $1}' )
		[ "$(echo $2 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
	ioraw3=$( echo $3 | awk 'NR==1 {print $1}' )
		[ "$(echo $3 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
	ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
	ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
	printf "%s" "$ioavg"
}

cpubench() {
	if hash $1 2>$NULL; then
		io=$( ( dd if=/dev/zero bs=512K count=$2 | $1 ) 2>&1 | grep 'copied' | awk -F, '{io=$NF} END {print io}' )
		if [[ $io != *"."* ]]; then
			printf "%4i %s" "${io% *}" "${io##* }"
		else
			printf "%4i.%s" "${io%.*}" "${io#*.}"
		fi
	else
		printf " %s not found on system." "$1"
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
	[[ -d $benchram ]] || mkdir $benchram
	mount -t tmpfs -o size=$sbram tmpfs $benchram/
	echostyle "RAM Speed:"
	iow1=$( ( dd if=/dev/zero of=$benchram/zero bs=512K count=$sbcount ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior1=$( ( dd if=$benchram/zero of=$NULL bs=512K count=$sbcount; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	iow2=$( ( dd if=/dev/zero of=$benchram/zero bs=512K count=$sbcount ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior2=$( ( dd if=$benchram/zero of=$NULL bs=512K count=$sbcount; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	iow3=$( ( dd if=/dev/zero of=$benchram/zero bs=512K count=$sbcount ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior3=$( ( dd if=$benchram/zero of=$NULL bs=512K count=$sbcount; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	echo "   Avg. write : $(averageio "$iow1" "$iow2" "$iow3") MB/s" | tee -a $log
	echo "   Avg. read  : $(averageio "$ior1" "$ior2" "$ior3") MB/s" | tee -a $log
	rm $benchram/zero
	umount $benchram
	rm -rf $benchram
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
		io1=$( write_test $writemb )
		echo -e "$io1" | tee -a $log
		echo -n "   2nd run    : " | tee -a $log
		io2=$( write_test $writemb )
		echo -e "$io2" | tee -a $log
		echo -n "   3rd run    : " | tee -a $log
		io3=$( write_test $writemb )
		echo -e "$io3" | tee -a $log
		ioraw1=$( echo $io1 | awk 'NR==1 {print $1}' )
		[ "`echo $io1 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
		ioraw2=$( echo $io2 | awk 'NR==1 {print $1}' )
		[ "`echo $io2 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
		ioraw3=$( echo $io3 | awk 'NR==1 {print $1}' )
		[ "`echo $io3 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
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
	printf ' Region: %s  https://bench.monster v.1.5.10 2022-05-30 \n' $region_name | tee -a $log
	printf " Usage : curl -LsO bench.monster/speedtest.sh; bash speedtest.sh -%s\n" $region_name | tee -a $log
	echo "" | tee -a $log
}

sharetest() {
	echo " Share results:"
	echo " - $result_speed"
	log_preupload
	case $1 in
	'ubuntu')
		share_link=$( curl -v --data-urlencode "content@$log_up" -d "poster=speedtest.sh" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 | \
			grep "Location" | awk '{print "https://paste.ubuntu.com"$3}' );;
	'haste' )
		share_link=$( curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}' );;
	'clbin' )
		share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
	esac

	# print result info
	echo " - $GEEKBENCH_URL" | tee -a $log
	echo " - $share_link"
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
		printf "ping error!"
	else
		printf "%3i.%s ms" "${ping_ms%.*}" "${ping_ms#*.}"
	fi
}

cleanup() {
	rm -f test_file_*;
	rm -f speedtest.py;
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
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

usa_bench(){
	region_name="USA"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_usa;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

in_bench(){
	region_name="India"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_in;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

europe_bench(){
	region_name="Europe"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_europe;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

asia_bench(){
	region_name="Asia"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_asia;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

china_bench(){
	region_name="China"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_china;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

sa_bench(){
	region_name="South-America"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_sa;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

au_bench(){
	region_name="AU-NZ"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_au;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

ukraine_bench(){
	region_name="Ukraine"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_ukraine;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}
lviv_bench(){
	region_name="Lviv"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_lviv;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}
meast_bench(){
	region_name="Middle-East"
	print_intro;
	benchinit;
	clear
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench4;
	iotest;
	write_io;
	print_speedtest_meast;
	next;
	print_end_time;
	cleanup;
	sharetest clbin;
}

log="$HOME/speedtest.log"
true > $log

case $1 in
	'info'|'-i'|'--i'|'-info'|'--info' )
		about;sleep 3;next;get_system_info;print_system_info;;
	'version'|'-v'|'--v'|'-version'|'--version')
		next;about;next;;
   	'gb5'|'-gb5'|'--gb5'|'geek5'|'-geek5'|'--geek5' )
		next;geekbench5;next;cleanup;;
	'gb'|'-gb'|'--gb'|'geek'|'-geek'|'--geek' )
		next;geekbench4;next;cleanup;;
	'io'|'-io'|'--io'|'ioping'|'-ioping'|'--ioping' )
		next;iotest;write_io;next;;
	'speed'|'-speed'|'--speed'|'-speedtest'|'--speedtest'|'-speedcheck'|'--speedcheck' )
		about;benchinit;next;print_speedtest;next;cleanup;;
	'as'|'-as'|'--aspeed'|'-aspeedtest'|'--aspeedtest'|'-aspeedcheck'|'--aspeedcheck' )
		about;benchinit;next;print_speedtest_asia;next;cleanup;;
	'ip'|'-ip'|'--ip'|'geoip'|'-geoip'|'--geoip' )
		about;benchinit;next;ip_info4;next;cleanup;;
	'bench'|'-a'|'--a'|'-all'|'--all'|'-bench'|'--bench'|'-Global' )
		bench_all;;
	'about'|'-about'|'--about' )
		about;;
	'usa'|'-usa'|'--usa'|'us'|'-us'|'--us'|'USA'|'-USA'|'--USA' )
		usa_bench;;
	'in'|'-india'|'--in'|'in'|'-in'|'IN'|'-IN'|'--IN' )
		in_bench;;
	'europe'|'-europe'|'--europe'|'eu'|'-eu'|'--eu'|'Europe'|'-Europe'|'--Europe' )
		europe_bench;;
	'asia'|'-asia'|'--asia'|'as'|'-as'|'--as'|'Asia'|'-Asia'|'--Asia' )
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
