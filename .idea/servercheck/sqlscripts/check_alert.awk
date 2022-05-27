$0 ~ /Errors in file/ {print $0}
$0 ~ /PMON: terminating instance due to error 600/ {print $0}
$0 ~ /Started recovery/{print $0}
$0 ~ /Archival required/{print $0}
$0 ~ /Instance terminated/ {print $0}
$0 ~ /Checkpoint not complete/ {print $0}
$1 ~ /ORA-/ { print $0; flag=1 }
$0 !~ /ORA-/ {if (flag==1){print $0; flag=0;print " "} }
$0 ~ /ERROR_AUDIT/ {print $0}
