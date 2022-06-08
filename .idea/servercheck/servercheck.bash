#!/bin/bash

# --------------------------------------------------------------------------+
#                  SERVER CHECK                                             |
#   Filename: servercheck.bash                                              |
#   Desc:                                                                   |
#       The script use to check server status.                              |
#       OS,Database,backups will be checked                                 |
#   Usage:                                                                  |
#       bash servercheck.bash                                               |
#                                                                           |
#   Author  : MLH                                                           |
#   Release : 20220606                                                      |
# --------------------------------------------------------------------------+

echo "##############################################################################################"
echo "##                                    CAUTION                                               ##"
echo "## 1. Oracle checking only work for single instance database, RAC and ADG is not supported! ##"
echo "## 2. CDB or PDB of 12c and above database is not suported!                                 ##"
echo "## 3. This script only check the oracle backup directory that named EXPDIR. IF you have     ##"
echo "##    another one, check it manually.                                                       ##"
echo "## 4. Supported platform: Redhat/CentOS/OracleLinux6,7,8. RockyLinux8.                      ##"
echo "## 5. Please make sure that the my.cnf file of the mysql database is in /etc, otherwise     ##"
echo "##    the script will not recognize it.                                                     ##"
echo "## 6. The backup of the MySQL database will be verified using the script mysqlbackup.sh     ##"
echo "##    Backups using other scripts are not supported.                                        ##"
echo "##############################################################################################"

read -n1 -p "Continue after reading the caution [y|n]?" answer
case $answer in
Y | y)
  echo "Fine, continue"
  ;;
N | n)
  echo "OK, Good bye!"
  exit
  ;;
*)
  echo "Error choice"
  exit
  ;;
esac

# ----------------------------------------------
# check root
# ----------------------------------------------

if [ "$(whoami)" != 'root' ]; then
  echo "$time You must use root to run the script！"
  exit 1
fi

# ----------------------------------------------
# make directory that result file stored
# ----------------------------------------------

mydirectory=$(pwd)
date=$( (date +%Y%m%d%H%M%S))
displaydate=$( (date +%Y-%m-%d\ %H:%M:%S))
mkdir ${mydirectory}/result${date}
resultdirectory=${mydirectory}/result${date}
touch ${resultdirectory}/serverinfo.txt
resultfile=${resultdirectory}/serverinfo.txt

# ----------------------------------------------
# check sqlscripts pkg
# ----------------------------------------------

if [ ! -e ${mydirectory}/sqlscripts.tar.gz ]; then
  echo "sqlscripts.tar.gz not found!" | tee -a ${resultfile}
  exit 1
else
  sqlscriptsmd5=$(md5sum ${mydirectory}/sqlscripts.tar.gz | awk {'print $1'})
  if [[ ${sqlscriptsmd5} != "c4098512f0c54ab3a4d07aea955fee28" ]]; then
    echo "sqlscripts.tar.gz is corrupted! Please upload again!" | tee -a ${resultfile}
    exit 1
  fi
fi
tar xvfz ${mydirectory}/sqlscripts.tar.gz >/dev/null

# ----------------------------------------------
# initialize serverversion 6 for linux 6. 7 for linux7,8
# ----------------------------------------------

serverversion=0

# ----------------------------------------------
# start checking
# ----------------------------------------------
echo "${displaydate} Start checking" | tee -a ${resultfile}

# ----------------------------------------------
# OS version
# ----------------------------------------------
osversion=$(cat /etc/system-release)
echo "************************************1.1 perating system version information:*************************************" >>${resultfile}
echo ${osversion} >>${resultfile}
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}
versionnum=${osversion#*release}
versionnum=${versionnum:0:2}
if [ $versionnum -eq 6 ]; then
  serverversion=6
elif [ $versionnum -eq 7 ]; then
  serverversion=7
elif [ $versionnum -eq 8 ]; then
  serverversion=7
else
  echo "Server version error, the script may not compatiable with the OS, please contact the developer!" | tee -a ${resultfile}
  echo $serverversion | tee -a ${resultfile}
  exit 1
fi

# ----------------------------------------------
# hostname
# ----------------------------------------------

echo "************************************************1.2 HOSTNAME*****************************************************" >>${resultfile}
hostname >>${resultfile}
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# check timezone
# ----------------------------------------------

echo "*************************************************1.3 TIMEZONE*****************************************************" >>${resultfile}
mytimezone=$(date -R)
echo $mytimezone >/tmp/timezonetmp
grep +0800 /tmp/timezonetmp >/dev/null
if [ $? -ne 0 ]; then
  echo "Timezone error!" | tee -a ${resultfile}
  echo "System timezone is ${mytimezone}" | tee -a ${resultfile}
  echo "Please use the following command to set the system time zone to Asia Shanghai" | tee -a ${resultfile}
  echo "ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime" | tee -a ${resultfile}
  echo "However, it should be noted that the time change brought by changing the time zone will affect the business system/database." | tee -a ${resultfile}
else
  cat /tmp/timezonetmp >>${resultfile}
  echo 'Timezone check ok!' >>${resultfile}
fi
rm -rf /tmp/timezonetmp
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# CPU
# ----------------------------------------------

echo "****************************************************1.4 CPU******************************************************" >>${resultfile}
lscpu >>${resultfile}
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

echo "**************************************************1.5 CPU_USAGE**************************************************" >>${resultfile}
TIME_INTERVAL=5
time=$(date "+%Y-%m-%d %H:%M:%S")
LAST_CPU_INFO=$(cat /proc/stat | grep -w cpu | awk '{print $2,$3,$4,$5,$6,$7,$8}')
LAST_SYS_IDLE=$(echo $LAST_CPU_INFO | awk '{print $4}')
LAST_TOTAL_CPU_T=$(echo $LAST_CPU_INFO | awk '{print $1+$2+$3+$4+$5+$6+$7}')
sleep ${TIME_INTERVAL}
NEXT_CPU_INFO=$(cat /proc/stat | grep -w cpu | awk '{print $2,$3,$4,$5,$6,$7,$8}')
NEXT_SYS_IDLE=$(echo $NEXT_CPU_INFO | awk '{print $4}')
NEXT_TOTAL_CPU_T=$(echo $NEXT_CPU_INFO | awk '{print $1+$2+$3+$4+$5+$6+$7}')
SYSTEM_IDLE=$(echo ${NEXT_SYS_IDLE} ${LAST_SYS_IDLE} | awk '{print $1-$2}')
TOTAL_TIME=$(echo ${NEXT_TOTAL_CPU_T} ${LAST_TOTAL_CPU_T} | awk '{print $1-$2}')
CPU_USAGE=$(echo ${SYSTEM_IDLE} ${TOTAL_TIME} | awk '{printf "%.2f", 100-$1/$2*100}')
echo "CPU Usage:${CPU_USAGE}%" >>${resultfile}

echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

echo "*************************************************1.6 Memory******************************************************" >>${resultfile}
free -m >>${resultfile}
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

echo "**************************************************1.7 Disk*******************************************************" >>${resultfile}
df -h >>${resultfile}
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

echo "***************************************************1.8 IP********************************************************" >>${resultfile}
ip a >>${resultfile}
ip route list >>${resultfile}
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# /var/log/messages check
# ----------------------------------------------

echo "*********************************************1.9 LinuxLogMessages************************************************" >>${resultfile}
tail -n 20000 /var/log/messages >/tmp/linuxerrorlog
cat /tmp/linuxerrorlog | awk -f ${mydirectory}/sqlscripts/check_linux.awk >${resultdirectory}/linux_error.log
if [ -e ${resultdirectory}/linux_error.log ]; then
  echo "Warning or errors found in linux error log, check ${resultdirectory}/linux_error.log for detail!" >>${resultfile}
else
  echo "No error or warnings found in linux error log" >>${resultfile}
  echo "CAUTION: No erros are found, it doesn't mean the OS is running without issues." >>${resultfile}
  echo "Please concact support, if you found any problems." >>${resultfile}
fi
rm -rf /tmp/linuxerrorlog

echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# cron status
# ----------------------------------------------

echo "**********************************************1.10 CRON**********************************************************" >>${resultfile}

if [ $serverversion -eq 6 ]; then
  echo "1.10.1 crond running status:" >>${resultfile}
  service crond status | head -9 >>${resultfile}
  echo "" >>${resultfile}
  echo "1.10.2 CRON LIST" >>${resultfile}
  echo "Min Hour Day Month Week" >>${resultfile}
  crontab -l >>${resultfile} 2>&1
  echo "" >>${resultfile}
  echo "1.10.3 CRON HISTORY" >>${resultfile}
  crontab -l 2>&1 | awk {'print $7'} | sed '/^$/d' >/tmp/crontask
  crontaskp=$(cat /tmp/crontask)
  if [[ ! ${crontaskp} ]]; then
    echo "No cron job!" >>${resultfile}
  else
    cat /tmp/crontask | while read line; do
      cat /var/log/cron | sed '/^$/d' | grep $line >>${resultfile}
    done
  fi
  rm -rf /tmp/crontask
fi

if [ $serverversion -eq 7 ]; then
  echo "1.10.1 crond running status:" >>${resultfile}
  systemctl status crond | head -9 >>${resultfile}
  echo "" >>${resultfile}
  echo "1.10.2 CRON TABLE" >>${resultfile}
  echo "Min Hour Day Month Week" >>${resultfile}
  crontab -l >>${resultfile} 2>&1
  echo "" >>${resultfile}
  echo "1.10.3 CRON HISTORY" >>${resultfile}
  crontab -l 2>&1 | awk {'print $7'} | sed '/^$/d' >/tmp/crontask
  crontaskp=$(cat /tmp/crontask)
  if [[ ! ${crontaskp} ]]; then
    echo "No cron job!" >>${resultfile}
  else
    cat /tmp/crontask | while read line; do
      cat /var/log/cron | sed '/^$/d' | grep $line >>${resultfile}
    done
  fi
  rm -rf /tmp/crontask
fi

echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# other app service status
# ----------------------------------------------

echo "***********************************************1.11 APPS*********************************************************" >>${resultfile}
echo "CAUTION: This check is only for those services that have been registered with the system services" >>${resultfile}
echo "nginx" >>/tmp/apps
echo "tomcat" >>/tmp/apps
echo "tomcat9" >>/tmp/apps
echo "sshd" >>/tmp/apps
echo "docker" >>/tmp/apps
echo "redis" >>/tmp/apps

if [ $serverversion -eq 6 ]; then
  cat /tmp/apps | while read line; do
    service $line status >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "++++++++++++++++++++++++++++++++++++++++++" >>${resultfile}
      echo "Service $line not found in the system" >>${resultfile}
    else
      echo "++++++++++++++++++++++++++++++++++++++++++" >>${resultfile}
      echo "Server $line status" >>${resultfile}
      service $line status | head -9 >>${resultfile} 2>&1
    fi
  done
fi

if [ $serverversion -eq 7 ]; then
  cat /tmp/apps | while read line; do
    /bin/systemctl status $line >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "++++++++++++++++++++++++++++++++++++++++++" >>${resultfile}
      echo "Service $line not found in the system" >>${resultfile}
    else
      echo "++++++++++++++++++++++++++++++++++++++++++" >>${resultfile}
      echo "Server $line status" >>${resultfile}
      systemctl status $line | head -9 >>${resultfile} 2>&1
    fi
  done
fi

rm -rf /tmp/apps
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# Oracle Database status
# ----------------------------------------------

echo "*************************************************2.1 ORACLE******************************************************" >>${resultfile}
id oracle >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Oracle not installed on this machine!" >>${resultfile}
else
  oracleprocess=$(ps -ef | grep ora_pmon | grep -v gre | grep -v color | wc -l)
  if [ ${oracleprocess} -lt 1 ]; then
    echo "Oracle not running on this machine!" >>${resultfile}
  else
    #oracle versions
    echo "2.1.1 Oracle versions" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_version.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_version" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_version.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst

    #oracle archive log
    echo "2.1.2 Oracle Archive Log Mode" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_archivelog.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_archivelog" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_archivelog.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >>${resultfile}

    #oracle fast_recover
    echo "2.1.3 Oracle Fast Recovery File" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_fastrecovery.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_fastrecovery.sql" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_fastrecovery.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >>${resultfile}

    #oracle Some Parameters
    echo "2.1.4 Oracle some parameters" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_parameters.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_parameters.sql" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_parameters.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >>${resultfile}

    #oracle Tablespaces
    echo "2.1.5 Oracle tablespaces:" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_tablespaces.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_tablespaces.sql" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_tablespaces.sql
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >>${resultfile}

    #oracle backup directory status
    echo "2.1.6 Oracle backup directory:" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_backupdirectory.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_backupdirectory.sql" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_backupdirectory.sql
    orabackupdir=$(cat ${resultdirectory}/oracleresulttmp.lst | grep EXPDIR | awk {'print $2'})
    if [ ! ${orabackupdir} ]; then
      echo "EXPDIR not found!" >>${resultfile}
    else
      ls -al ${orabackupdir} >>${resultfile}
    fi
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >>${resultfile}

    #oracle patch list
    echo "2.1.7 Oracle patches:" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    runuser -l oracle -c '$ORACLE_HOME/OPatch/opatch lspatches' >>${resultfile}
    echo "" >>${resultfile}

    #oracle alert log
    echo "2.1.8 Oracle alert log:" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    sed -i $"1iSPOOL\ ${resultdirectory}/oracleresulttmp" ${mydirectory}/sqlscripts/sql_diagtrace.sql
    chmod -R 777 ${resultdirectory}
    runuser -l oracle -c "sqlplus / as sysdba @${mydirectory}/sqlscripts/sql_diagtrace.sql" >/dev/null 2>&1
    cat ${resultdirectory}/oracleresulttmp.lst >>${resultfile}
    sed -i '1d' ${mydirectory}/sqlscripts/sql_diagtrace.sql
    oratracedir=$(cat ${resultdirectory}/oracleresulttmp.lst | grep Trace | awk {'print $3'})
    tracefilename=$(
      cd ${oratracedir}
      ls -al alert* | awk {'print $9'}
    )
    tracefile=${oratracedir}/${tracefilename}
    tail -n 20000 ${tracefile} >/tmp/tmpalertlog
    cat /tmp/tmpalertlog | awk -f ${mydirectory}/sqlscripts/check_alert.awk >${resultdirectory}/ora_alert.log
    if [ -e ${resultdirectory}/ora_alert.log ]; then
      echo "Warning or errors found in oracle alert log, check ${resultdirectory}/ora_alert.log for detail!" >>${resultfile}
    else
      echo "No error or warnings found in oracle alert log" >>${resultfile}
      echo "CAUTION: No erros are found, it doesn't mean the database is running without issues." >>${resultfile}
      echo "Please concact support, if you found any problems." >>${resultfile}
    fi
    rm -rf /tmp/tmpalertlog
    rm -rf ${resultdirectory}/oracleresulttmp.lst
    echo "" >>${resultfile}
  fi
fi
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

# ----------------------------------------------
# Mysql Database Check
# ----------------------------------------------

echo "*************************************************3.1 MySQL*******************************************************" >>${resultfile}
if [ ! -e /etc/my.cnf ]; then
  echo "/etc/my.cnf not found! MySQL may not installed on this machine!" >>${resultfile}
else
  #MySQL running check
  mysqlprocess=$(ps -ef | grep mysqld | grep -v gre | grep -v color | wc -l)
  if [ ${mysqlprocess} -lt 1 ]; then
    echo "MySQL not running on this machine!" >>${resultfile}
  else
    #MySQL Password input
    echo "Please type in the root passowrd of MySQL (Press ENTER if root password is empty)"
    read -s mysqlpasswd
    DB_PASSWORD=${mysqlpasswd}
    DB_PASSWORD_LEN=""
    DB_PASSWORD_LEN=${#DB_PASSWORD}
    if [ ${DB_PASSWORD_LEN} -eq 0 ]; then
      mysql -uroot -e quit >/tmp/SQL_RESULT 2>&1
    else
      mysql -uroot -p${DB_PASSWORD} -e quit >/tmp/SQL_RESULT 2>&1
    fi
    cat /tmp/SQL_RESULT | grep ERROR
    if [ $? -ne 0 ]; then
      echo "Right Password !"
    else
      echo "Wrong Password !"
      exit
    fi
    rm -rf /tmp/SQL_RESULT

    #MySQL version
    echo "3.1.1 MySQL version" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    mysql -uroot -p${DB_PASSWORD} -e "use mysql;select version()" 2>&1 | grep -v "mysql" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    echo "" >>${resultfile}

    #MySQL datafile
    echo "3.1.2 MySQL datafile" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    mysqldatadir=$(cat /etc/my.cnf | grep datadir | cut -d '=' -f 2)
    ls -al ${mysqldatadir} >>${resultfile}
    du -sh ${mysqldatadir} >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    echo "" >>${resultfile}

    #MySQL backup
    echo "3.1.3 MySQL backup" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    crontab -l 2>&1 >/tmp/crontabtmp
    cat /tmp/crontabtmp | grep mysqlbackup.sh > /dev/null
    if [ $? -ne 0 ]; then
      echo "mysqlbackup scripts not found! Can not check the status of mysql backup!" >>${resultfile}
    else
      mysqlbackupdir=$(cat /tmp/crontabtmp | grep mysqlbackup.sh | awk {'print $7'})
      mysqkbackuploc=$(cat ${mysqlbackupdir} | grep backupdirectoryname= | cut -d '=' -f 2)
      ls -al ${mysqkbackuploc} >>${resultfile}
      du -sh ${mysqkbackuploc} >>${resultfile}
    fi
    rm -rf /tmp/crontabtmp
    echo "----------------------------------------------------------------------" >>${resultfile}
    echo "" >>${resultfile}

    #MySQL log
    echo "3.1.4 MySQL log" >>${resultfile}
    echo "----------------------------------------------------------------------" >>${resultfile}
    mysqlerrorlog=$(cat /etc/my.cnf | grep log-error | cut -d '=' -f 2)
    tail -n 20000 ${mysqlerrorlog} >/tmp/tmpmysqlalertlog
    cat /tmp/tmpmysqlalertlog | awk -f ${mydirectory}/sqlscripts/check_mysqlerror.awk >${resultdirectory}/mysql_error.log
    if [ -e ${resultdirectory}/mysql_error.log ]; then
      echo "Warning or errors found in mysql error log, check ${resultdirectory}/mysql_error.log for detail!" >>${resultfile}
    else
      echo "No error or warnings found in mysql error log" >>${resultfile}
      echo "CAUTION: No erros are found, it doesn't mean the database is running without issues." >>${resultfile}
      echo "Please concact support, if you found any problems." >>${resultfile}
    fi
    rm -rf /tmp/tmpmysqlalertlog
    echo "----------------------------------------------------------------------" >>${resultfile}
  fi
fi
echo "*****************************************************************************************************************" >>${resultfile}
echo "" >>${resultfile}

rm -rf ${mydirectory}/sqlscripts
displaydate=$( (date +%Y-%m-%d\ %H:%M:%S))
echo "${displaydate} end progress, report saved to ${resultfile}." | tee -a ${resultfile}
