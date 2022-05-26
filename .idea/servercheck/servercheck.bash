#!/bin/bash

# BY MLH20220524
#############################################################################################
##                                   CAUTION                                               ##
## 1.Oracle checking only work for single instance database, RAC and ADG is not supported! ##
## 2.CDB or PDB database is not suported either!                                           ##
## 3.This script only check the oracle backup directory that named EXPDIR. IF you have     ##
##   another one, check it manually.                                                       ##
#############################################################################################

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
echo "**************************************Operating system version information:**************************************" >> ${resultfile}
echo ${osversion} >> ${resultfile}
echo "*****************************************************************************************************************" >> ${resultfile}
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
echo "****************************************************HOSTNAME*****************************************************" >> ${resultfile}
hostname >> ${resultfile}
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#check timezone
echo "****************************************************TIMEZONE*****************************************************" >> ${resultfile}
mytimezone=`date -R`
echo $mytimezone > /tmp/timezonetmp
grep +0800 /tmp/timezonetmp > /dev/null
if [ $? -ne 0 ]
  then
    echo "Timezone error!" | tee -a ${resultfile}
    echo "System timezone is ${mytimezone}" | tee -a ${resultfile}
    echo "Please use the following command to set the system time zone to Asia Shanghai" | tee -a ${resultfile}
    echo "ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime" | tee -a ${resultfile}
    echo "However, it should be noted that the time change brought by changing the time zone will affect the business system/database." | tee -a ${resultfile}
  else
    cat /tmp/timezonetmp >> ${resultfile}
    echo 'Timezone check ok!' >> ${resultfile}
fi
rm -rf /tmp/timezonetmp
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#CPUs
echo "********************************************************CPUs*****************************************************" >> ${resultfile}
lscpu >> ${resultfile}
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "******************************************************CPU_USAGE**************************************************" >> ${resultfile}
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

echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "*****************************************************Memory******************************************************" >> ${resultfile}
free -m >> ${resultfile}
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "******************************************************Disk*******************************************************" >> ${resultfile}
df -h >> ${resultfile}
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

echo "*******************************************************IP********************************************************" >> ${resultfile}
ip a >> ${resultfile}
ip route list >> ${resultfile}
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#/var/log/messages check

echo "*************************************************LinuxLogMessages************************************************" >> ${resultfile}
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

echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#cron status
echo "***************************************************CRON**********************************************************" >> ${resultfile}
if [ $serverversion -eq 6 ]
  then
    echo "crond running status:" >> ${resultfile}
    service crond status | head -9 >> ${resultfile}
    echo "" >> ${resultfile}
    echo "CRON TABLE" >> ${resultfile}
    crontab -l >> ${resultfile} 2>&1
    echo "" >> ${resultfile}
    echo "CRON HISTORY" >> ${resultfile}
    crontab -l | awk {'print $7'} > /tmp/crontask
    cat /tmp/crontask | while read line
      do
        cat /var/log/cron | grep $line >> ${resultfile}
      done
    rm -rf /tmp/crontask
fi
if [ $serverversion -eq 7 ]
  then
    echo "crond running status:" >> ${resultfile}
    systemctl status crond | head -9 >> ${resultfile}
    echo "" >> ${resultfile}
    echo "CRON TABLE" >> ${resultfile}
    crontab -l >>${resultfile} 2>&1
    echo "" >> ${resultfile}
    echo "CRON HISTORY" >> ${resultfile}
    crontab -l | awk {'print $7'} > /tmp/crontask
    cat /tmp/crontask | while read line
      do
        cat /var/log/cron | grep $line >> ${resultfile}
      done
    rm -rf /tmp/crontask
fi
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#other app service status
echo "****************************************************APPS*********************************************************" >> ${resultfile}
echo "CAUTION: This check is only for those services that have been registered with the system services" >> ${resultfile}
echo "nginx" >> /tmp/apps
echo "tomcat" >> /tmp/apps
echo "sshd" >> /tmp/apps
echo "docker" >> /tmp/apps
echo "redis" >> /tmp/apps
if [ $serverversion -eq 6 ]
  then
    cat /tmp/apps | while read line
    do
      service $line status > /dev/null 2>&1
      if [ $? -ne 0 ]
        then
          echo "*****************************************************************************************************************" >> ${resultfile}
          echo "Service $line not found in the system" >> ${resultfile}
        else
          echo "*****************************************************************************************************************" >> ${resultfile}
          echo "Server $line status" >> ${resultfile}
          service $line status | head -9 >> ${resultfile} 2>&1
      fi
    done
fi
if [ $serverversion -eq 7 ]
  then
    cat /tmp/apps | while read line
    do
      /bin/systemctl status $line > /dev/null 2>&1
      if [ $? -ne 0 ]
        then
          echo "++++++++++++++++++++++++++++++++++++++++++" >> ${resultfile}
          echo "Service $line not found in the system" >> ${resultfile}
        else
          echo "++++++++++++++++++++++++++++++++++++++++++" >> ${resultfile}
          echo "Server $line status" >> ${resultfile}
          systemctl status $line | head -9 >> ${resultfile} 2>&1
      fi
    done
fi
rm -rf /tmp/apps
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}

#Oracle Database
echo "*****************************************************ORACLE******************************************************" >> ${resultfile}
#if oracle installed on the server
id oracle > /dev/null
if [ $? -ne 0 ]
  then
    echo "Oracle not installed on this machine!" >> ${resultfile}
  else
    #oracle versions
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_version.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_version" > /dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >> ${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_version.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst

    #oracle archive log
    echo "Oracle Archive Log Mode" >> ${resultfile}
    echo "----------------------------------------------------------------------" >> ${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_archivelog.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_archivelog" > /dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >> ${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_archivelog.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >> ${resultfile}

    #oracle fast_recover
    echo "Oracle Fast Recovery File" >> ${resultfile}
    echo "----------------------------------------------------------------------" >> ${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_fastrecovery.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_fastrecovery.sql" > /dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >> ${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_fastrecovery.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >> ${resultfile}

    #oracle Some Parameters
    echo "Oracle some parameters" >> ${resultfile}
    echo "----------------------------------------------------------------------" >> ${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_parameters.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_parameters.sql" > /dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >> ${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_parameters.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >> ${resultfile}

    #oracle Tablespaces
    echo "Oracle tablespaces:" >> ${resultfile}
    echo "----------------------------------------------------------------------" >> ${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_tablespaces.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_tablespaces.sql" > /dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >> ${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_tablespaces.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >> ${resultfile}

    #oracle backup status

fi
echo "*****************************************************************************************************************" >> ${resultfile}
echo "" >> ${resultfile}
