#!/bin/bash

# BY MLH20220524

#check root
if [ "$(whoami)" != 'root' ]
  then
    echo "$time You must use root to run the script！"
    exit 1;
fi

#initialize serverversion 6 for linux 6. 7 for linux7,8
serverversion=0

#make directory that result file stored
mydirectory=$(pwd)
date=`(date +%Y%m%d%H%M%S)`
mkdir ${mydirectory}/result${date}
resultdirectory=${mydirectory}/result${date}
touch ${resultdirectory}/serverinfo.txt
resultfile=${resultdirectory}/serverinfo.txt

#start checking
echo "$date Start checking" | tee -a ${resultfile}

#OS version
osversion=$(cat /etc/system-release)
echo "***********Operating system version information:**********" >> ${resultfile}
echo ${osversion} >> ${resultfile}
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}
versionnum=${osversion#*release}
versionnum=${versionnum:0:2}
if [ $versionnum -eq 6 ]
  then
    serverversion=6
  elif [ $versionnum -eq 7 ]
    then
      serverversion=7
  elif [ $versionnum -eq 8 ]
    then
      serverversion=7
  else
    echo "Server version error, the script may not compatiable with the OS, please contact the developer!" | tee -a ${resultfile}
    echo $serverversion | tee -a ${resultfile}
    exit 1
fi

#hostname
echo "**********************HOSTNAME****************************" >> ${resultfile}
hostname >> ${resultfile}
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#check and setting timezone
mytimezone=`date -R`
echo $mytimezone >> /tmp/timezonetmp
grep +0800 /tmp/timezonetmp
if [ $? -ne 0 ]
  then
     ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
     echo "Timezone error!" | tee -a ${resultfile}
     echo "System timezone is ${mytimezone}" | tee -a ${resultfile}
     echo "Please use the following command to set the system time zone to Asia Shanghai" | tee -a ${resultfile}
     echo "ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime" | tee -a ${resultfile}
     echo "However, it should be noted that the time change brought by changing the time zone will affect the business system/database." | tee -a ${resultfile}
  else
    echo 'Timezone check!' >> ${resultfile}
fi
rm -rf /tmp/timezonetmp

#CPUs
echo "**************************CPUs****************************" >> ${resultfile}
lscpu >> ${resultfile}
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "***********************CPU_USAGE**************************" >> ${resultfile}
TIME_INTERVAL=5
time=$(date "+%Y-%m-%d %H:%M:%S")
LAST_CPU_INFO=$(cat /proc/stat | grep -w cpu | awk '{print $2,$3,$4,$5,$6,$7,$8}')
LAST_SYS_IDLE=$(echo $LAST_CPU_INFO | awk '{print $4}')
LAST_TOTAL_CPU_T=$(echo $LAST_CPU_INFO | awk '{print $1+$2+$3+$4+$5+$6+$7}')
sleep ${TIME_INTERVAL}
NEXT_CPU_INFO=$(cat /proc/stat | grep -w cpu | awk '{print $2,$3,$4,$5,$6,$7,$8}')
NEXT_SYS_IDLE=$(echo $NEXT_CPU_INFO | awk '{print $4}')
NEXT_TOTAL_CPU_T=$(echo $NEXT_CPU_INFO | awk '{print $1+$2+$3+$4+$5+$6+$7}')
SYSTEM_IDLE=`echo ${NEXT_SYS_IDLE} ${LAST_SYS_IDLE} | awk '{print $1-$2}'`
TOTAL_TIME=`echo ${NEXT_TOTAL_CPU_T} ${LAST_TOTAL_CPU_T} | awk '{print $1-$2}'`
CPU_USAGE=`echo ${SYSTEM_IDLE} ${TOTAL_TIME} | awk '{printf "%.2f", 100-$1/$2*100}'`
echo "CPU Usage:${CPU_USAGE}%" >> ${resultfile}

echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "*************************Memory***************************" >> ${resultfile}
free -m >> ${resultfile}
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "***************************Disk***************************" >> ${resultfile}
df -h >> ${resultfile}
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "****************************IP****************************" >> ${resultfile}
ip a >> ${resultfile}
ip route list >> ${resultfile}
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#/var/log/messages check

echo "*********************LinuxLogMessages*********************" >> ${resultfile}
checkdays=30
i=0
errorsign=0

while [ $i -lt $checkdays ]
do
  prev_count=0
  count=$(grep -i "`date --date="$i day ago" '+%b %e'`" /var/log/messages | egrep -wi 'warning|error|critical' | wc -l)
  if [ "$prev_count" -lt "$count" ]
    then
      echo "WARNING: Errors found in /var/log/messages on "`date --date="$i day ago" '+%Y-%m-%d'`"" >> ${resultfile}
      errorsign=1
  fi
  i=`expr $i + 1`
done

if [ $errorsign -eq 1 ]
  then
    echo "Snapshot will be copy to ${resultdirectory}/messages.log, check it for detail!" >> ${resultfile}
fi

if [ $errorsign -lt 1 ]
  then
    echo "No errors found in /var/log/messages" >> ${resultfile}
    echo "CAUTION: No erros are found,it doesn't mean the os is running without problems." >> ${resultfile}
    echo "Please concact support, if you found any problems." >> ${resultfile}
fi

cat /var/log/messages | grep warning >> ${resultdirectory}/messages.log
cat /var/log/messages | grep error >> ${resultdirectory}/messages.log
cat /var/log/messages | grep critical >> ${resultdirectory}/messages.log

echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#cron status
echo "*************************CRON*****************************" >> ${resultfile}
if [ $serverversion -eq 6 ]
  then
    echo "crond running status:" >> ${resultfile}
    service crond status >> ${resultfile}
    echo "" >> ${resultfile}
    echo "CRON TABLE" >> ${resultfile}
    crontab -l 2>> ${resultfile}
fi
if [ $serverversion -eq 7 ]
  then
    echo "crond running status:" >> ${resultfile}
    systemctl status crond >> ${resultfile}
    echo "" >> ${resultfile}
    echo "CRON TABLE" >> ${resultfile}
    crontab -l 2>> ${resultfile}
fi
echo "**********************************************************" >> ${resultfile}
echo "" >> ${resultfile}
