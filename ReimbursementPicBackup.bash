#!/bin/bash
#
# By MLH 20220509
# Caution: You must install ftp zip in the system first!
# Usage: Put this script to /cron, and type crontab -e to edit execution plan
# 0 0 * * * bash /cron/ReimbursementPicBackup.bash.bash
# backupdirectorydestination: The directory that zip file stored.
# backupdirectory: The directory that you are planed to be backup.
# ftpuser: The ftp server account name.
# ftppasswd: Password of the ftp account.
# Port: Default ftp port 21, it can be changed if it is required by security reason.
# Prefix: Prefix of tar file.

backupdirectorydestination=/backup
backupdirectory=/reimbursement-attachments
ftpuser=test
ftppasswd=test
ftpip=172.0.32.170
port=21
date=`(date +%Y%m%d)`
l_time=`(date +%Y%m%d" "%H":"%M":"%S)`
prefix=reim

#ftp tool check
which ftp
if [ $? -eq 1 ]
  then


tar cvPfz ${backupdirectorydestination}/${prefix}backup${date}.tar.gz ${backupdirectory}

ftp -in 2>>ftp_err<<EOF
open $ftpip $port
user $ftpuser $ftppasswd
binary
put ${prefix}backup${date}.tar.gz
bye
EOF
l_time=`(date +%Y%m%d" "%H":"%M":"%S)`

if [ -s ftp_err ]
then
  cat ftp_err >> ${prefix}backup_event
  echo "tranmission error"
  echo "$l_time tranmission error $tran_file" >> ${prefix}backup_event
else
  sed  -i "s/${tran_file}$/$tran_file|tran succ/g" ${prefix}backup_history
  echo "tranmission success"
  echo "$l_time tranmission success $tran_file" >> ${prefix}backup_event
fi

find $backupdirectorydestination/*.tar.gz -type f -mtime +1 -exec rm -rf {} \;
