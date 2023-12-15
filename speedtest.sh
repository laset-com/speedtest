#!/usr/bin/env bash

bench_v="v1.7.4"
bench_d="2023-12-15"
about() {
	echo ""
	echo " ========================================================= "
	echo " \            Speedtest https://bench.monster            / "
	echo " \    System info, Geekbench, I/O test and speedtest     / "
	echo " \                  $bench_v    $bench_d                 / "
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
	if  [ ! -e '/usr/bin/python3' ]; then
	        echo " Installing Python3 ..."
	            if [ "${release}" == "centos" ]; then
	                    yum -y install python3 > /dev/null 2>&1
			    alternatives --set python3 /usr/bin/python3 > /dev/null 2>&1
	                else
	                    apt-get -y install python3 > /dev/null 2>&1
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
	speed_test '18956' 'USA, New York (Hivelocity)    ' 'http://speedtest.nyc.hivelocity.net'
	speed_test '17384' 'USA, Chicago (Windstream)     ' 'http://chicago02.speedtest.windstream.net'
	speed_test '1763' 'USA, Houston (Comcast)        ' 'http://po-1-xar01.greenspoint.tx.houston.comcast.net'
	speed_test '1779' 'USA, Miami (Comcast)          ' 'http://50.208.232.125'
	speed_test '18401' 'USA, Los Angeles (Windstream) ' 'http://la02.speedtest.windstream.net'
	speed_test '26922' 'UK, London (toob Ltd)         ' 'http://185.82.8.1'
	speed_test '24215' 'France, Paris (Orange)        ' 'http://178.21.176.100'
	speed_test '20507' 'Germany, Berlin (DNS:NET)     ' 'http://speedtest01.dns-net.de'
	speed_test '21378' 'Spain, Madrid (MasMovil)      ' 'http://speedtest-mad.masmovil.com'
	speed_test '395' 'Italy, Rome (Unidata)         ' 'http://speedtest2.unidata.it'
	speed_test '23647' 'India, Mumbai (Tatasky)       ' 'http://speedtestmum.tataskybroadband.com'
	speed_test '51914' 'Singapore (StarHub)           ' 'http://co2dsvr03.speedtest.starhub.com'
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
	printf "%-76s\n" "-" | sed 's/\s/-/g' | tee -a $log
        speed_test '' 'Nearby                         '
	printf "%-76s\n" "-" | sed 's/\s/-/g' | tee -a $log
	speed_test '18956' 'USA, New York (Hivelocity)     ' 'http://speedtest.nyc.hivelocity.net'
	speed_test '1774' 'USA, Boston (Comcast)          ' 'http://po-2-rur102.needham.ma.boston.comcast.net'
	speed_test '1775' 'USA, Baltimore, MD (Comcast)   ' 'http://po-1-rur101.capitolhghts.md.bad.comcast.net'
	speed_test '17387' 'USA, Atlanta (Windstream)      ' 'http://atlanta02.speedtest.windstream.net'
	speed_test '1779' 'USA, Miami (Comcast)           ' 'http://be-111-pe12.nota.fl.ibone.comcast.net'
	speed_test '1764' 'USA, Nashville (Comcast)       ' 'http://be-304-cr23.nashville.tn.ibone.comcast.net'
	speed_test '10152' 'USA, Indianapolis (CenturyLink)' 'http://indianapolis.speedtest.centurylink.net'
	speed_test '10138' 'USA, Cleveland (CenturyLink)   ' 'http://cleveland.speedtest.centurylink.net'
	speed_test '1778' 'USA, Detroit, MI (Comcast)     ' 'http://ae-97-rur101.taylor.mi.michigan.comcast.net'
	speed_test '17384' 'USA, Chicago (Windstream)      ' 'http://chicago02.speedtest.windstream.net'
	speed_test '4557' 'USA, St. Louis (Elite Fiber)   ' 'http://speed.elitesystemsllc.com'
	speed_test '2917' 'USA, Minneapolis (US Internet) ' 'http://speedtest.usiwireless.com'
	speed_test '17709' 'USA, Kansas City (UPNfiber)    ' 'http://speedtest.upnfiber.com'
	speed_test '1763' 'USA, Houston (Comcast)         ' 'http://po-1-xar01.greenspoint.tx.houston.comcast.net'
	speed_test '8862' 'USA, Denver (CenturyLink)      ' 'http://denver.speedtest.centurylink.net'
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
	speed_test '26922' 'UK, London (toob Ltd)           ' 'http://185.82.8.1'
	speed_test '29076' 'Netherlands, Amsterdam (XS News)' 'http://speedtest.xsnews.nl'
	speed_test '20507' 'Germany, Berlin (DNS:NET)       ' 'http://speedtest01.dns-net.de'
	speed_test '27345' 'Germany, Munich (InterNetX)     ' 'http://speedtest.internetx.de'
	speed_test '26852' 'Sweden, Stockholm (SUNET)       ' 'http://fd.sunet.se'
	speed_test '8018' 'Norway, Oslo (NextGenTel)       ' 'http://sp2.nextgentel.no'
	speed_test '24215' 'France, Paris (Orange)          ' 'http://178.21.176.100'
	speed_test '21378' 'Spain, Madrid (MasMovil)        ' 'http://speedtest-mad.masmovil.com'
	speed_test '395' 'Italy, Rome (Unidata)           ' 'http://speedtest2.unidata.it'
	speed_test '21975' 'Czechia, Prague (Nordic Telecom)' 'http://ookla.nordictelecom.cz'
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
	speed_test '1131' 'Sri Lanka, Colombo (Telecom PLC)' 'http://speedtest2.sltnet.lk'
	speed_test '7147' 'Bangladesh, Dhaka (Skytel)      ' 'http://sp1.cosmocom.net'
	speed_test '14062' 'Myanmar, Yangon (5BB Broadband) ' 'http://5bbbroadband.com'
	speed_test '26845' 'Laos, Vientaine (Mangkone)      ' 'http://speedtest.mangkone.com'
	speed_test '13871' 'Thailand, Bangkok (CAT Telecom) ' 'http://catspeedtest.net'
	speed_test '10798' 'Cambodia, Phnom Penh (Today)    ' 'http://100ge0-36.core1.pnh1.he.net'
	speed_test '9174' 'Vietnam, Hanoi (MOBIFONE)       ' 'http://st1.mobifone.vn'
	speed_test '27261' 'Malaysia, Kuala Lumpur (Extreme)' 'http://kl-speedtest.ebb.my'
	speed_test '51914' 'Singapore (StarHub)             ' 'http://co2dsvr03.speedtest.starhub.com'
	speed_test '11118' 'Indonesia, Jakarta (My Republic)' 'http://158.140.187.5'
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
	speed_test '11488' 'Brazil, Sao Paulo (Criare)         ' 'http://ookla.spcom.net.br'
	speed_test '11435' 'Brazil, Fortaleza (Netonda)        ' 'http://speedtest.netonda.com.br'
	speed_test '18126' 'Brazil, Manaus (Claro)             ' 'http://spd7.claro.com.br'
	speed_test '11683' 'Colombia, Bogota (Level 3)         ' 'http://speedtest.globalcrossing.com.co'
	speed_test '31043' 'Ecuador, Ambato (EXTREME)          ' 'http://speed.extreme.net.ec'
	speed_test '5272' 'Peru, Lima (Fiberluxperu)          ' 'http://medidor.fiberluxperu.com'
	speed_test '1053' 'Bolivia, La Paz (Nuevatel)         ' 'http://speedtest.nuevatel.com'
	speed_test '6776' 'Paraguay, Asuncion (TEISA)         ' 'http://sp1.teisa.com.py'
	speed_test '21436' 'Chile, Santiago (Movistar)         ' 'http://speedtest-h5-10g.movistarplay.cl'
	speed_test '5181' 'Argentina, Buenos Aires (Claro)    ' 'http://speedtest.claro.com.ar'
	speed_test '10315' 'Argentina, Cordoba (Personal)      ' 'http://st1res.personal.com.ar'
	speed_test '1546' 'Uruguay, Montevideo (Antel)        ' 'http://speedtest.movistar.com.uy'
	 
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
	speed_test '18247' 'Australia, Adelaide (Vocus)   ' 'http://speedtest-ade.vocus.net'
	speed_test '8976' 'Australia, Hobart (Optus)     ' 'http://speedtest.tas.optusnet.com.au'
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
	speed_test '26293' 'Ukraine, Lviv (LinkCom) ' 'http://st.lc.lviv.ua'
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
	else
	echo "" | tee -a $log
	echo -e " Performing Geekbench v4 CPU Benchmark test. Please wait..."

	GEEKBENCH_PATH=$HOME/geekbench
	mkdir -p $GEEKBENCH_PATH
	curl -s https://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz  | tar xz --strip-components=1 -C $GEEKBENCH_PATH &>/dev/null
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
	curl -s https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz | tar xz --strip-components=1 -C $GEEKBENCH_PATH &>/dev/null
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

	GEEKBENCH_PATH=$HOME/geekbench
	mkdir -p $GEEKBENCH_PATH
	curl -s https://cdn.geekbench.com/Geekbench-6.2.1-Linux.tar.gz | tar xz --strip-components=1 -C $GEEKBENCH_PATH &>/dev/null
	GEEKBENCH_TEST=$($GEEKBENCH_PATH/geekbench6 2>/dev/null | grep "https://browser")
	GEEKBENCH_URL=$(echo -e $GEEKBENCH_TEST | head -1)
	GEEKBENCH_URL_CLAIM=$(echo $GEEKBENCH_URL | awk '{ print $2 }')
	GEEKBENCH_URL=$(echo $GEEKBENCH_URL | awk '{ print $1 }')
	sleep 15
	GEEKBENCH_SCORES=$(curl -s $GEEKBENCH_URL | grep "div class='score'")
	GEEKBENCH_SCORES_SINGLE=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $3 }')
	GEEKBENCH_SCORES_MULTI=$(echo $GEEKBENCH_SCORES | awk -v FS="(<|>)" '{ print $7 }')
	
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

	echo -e " ASN & ISP            : $asn" | tee -a $log
	echo -e " Organization         : $org" | tee -a $log
	echo -e " Location             : $city, $country ($countryCode)" | tee -a $log
	echo -e " Region               : $region" | tee -a $log
}

ip_info4(){
	isp=$(python3 tools.py geoip isp)
	as_tmp=$(python3 tools.py geoip as)
	asn=$(echo $as_tmp | awk -F ' ' '{print $1}')
	org=$(python3 tools.py geoip org)
	country=$(python3 tools.py geoip country)
	city=$(python3 tools.py geoip city)
	#countryCode=$(python3 tools.py geoip countryCode)
	region=$(python3 tools.py geoip regionName)

	echo -e " Location     : $country, $city ($region)" | tee -a $log
	#echo -e " Region       : $region" | tee -a $log
	echo -e " ASN & ISP    : $asn, $isp / $org" | tee -a $log
	#echo -e " Organization : $org" | tee -a $log

	rm -rf tools.py
}

machine_location(){
	isp=$(python3 tools.py geoip isp)
	as_tmp=$(python3 tools.py geoip as)
	asn=$(echo $as_tmp | awk -F ' ' '{print $1}')
	org=$(python3 tools.py geoip org)
	country=$(python3 tools.py geoip country)
	city=$(python3 tools.py geoip city)
	#countryCode=$(python3 tools.py geoip countryCode)
	region=$(python3 tools.py geoip regionName)	

	echo -e " Machine location: $country, $city ($region)"
	echo -e " ISP & ORG: $asn, $isp / $org"

	rm -rf tools.py
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
	[[ -z "$IPV4_CHECK" ]] && ONLINE="\xE2\x9D\x8C Offline / " || ONLINE="\xE2\x9C\x94 Online / "
	[[ -z "$IPV6_CHECK" ]] && ONLINE+="\xE2\x9D\x8C Offline" || ONLINE+="\xE2\x9C\x94 Online"
	echo -e " IPv4/IPv6    : $ONLINE" | tee -a $log
	echo -e " Uptime       : $up" | tee -a $log
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
	printf ' Region: %s  https://bench.monster '$bench_v' '$bench_d' \n' $region_name | tee -a $log
	printf " Usage : curl -sL bench.monster | bash -s -- -%s\n" $region_name | tee -a $log
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
	'clbin' )
		#share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
		sprunge_link=$(curl -sF 'sprunge=<-' https://sprunge.us < $log);;
	esac

	# Replace "http://" with "https://"
	share_link=$(echo "$sprunge_link" | sed 's/http:/https:/')

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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
	next;
	get_system_info;
	print_system_info;
	ip_info4;
	next;
	geekbench;
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
