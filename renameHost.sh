#! /bin/bash  
DMserver=/home/sigvalue/automation/postscript_server/DMserver.txt
OCserver=/home/sigvalue/automation/postscript_server/OCserver.txt
DBserver=/home/sigvalue/automation/postscript_server/DBserver.txt
DMS=dm0
OCS=oc0
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
CYAN="\e[96m"
read  -p "enter the environment initials and postfix: " EVT
read  -p "enter the region shortcode and internet zone: " REGION
read  -p "enter the DB server initial number, eg 01 or 03 etc: " DBNUM


PING()
{
if [ $? -gt 0 ] 
then 
echo -e "$RED destination unreachable...\e[0m"
continue
fi
}


DMS()
{

NUMBER=2
VAR=`hostname -i`
echo -e "$GREEN changing hostname of server: $VAR and setting it to\e[0m" "$YELLOW 173dm01$EVT$REGION\e[0m"
hostnamectl set-hostname 173dm01$EVT$REGION
for i in `cat $DMserver`
do
VALUE=173$DMS$NUMBER$EVT$REGION 
echo -e "$CYAN pinging $i...\e[0m"
ping -c 1 $i &> /dev/null
PING
ssh root@$i /bin/bash << EOF
echo -e "$GREEN changing hostname of server: $i and setting it to\e[0m" "$YELLOW $VALUE\e[0m"
hostnamectl set-hostname $VALUE
EOF
#NUMBER=NUMBER+1
NUMBER=$((NUMBER+1)) 
done
}

OCS()
{
NUMBER=1
for i in `cat $OCserver`
do
VALUE=173$OCS$NUMBER$EVT$REGION
echo -e "$CYAN pinging $i...\e[0m"
ping -c 1 $i &> /dev/null
PING
ssh root@$i /bin/bash << EOF
echo -e "$GREEN changing hostname of server: $i and setting it to\e[0m" "$YELLOW $VALUE\e[0m"
hostnamectl set-hostname $VALUE
EOF
NUMBER=$((NUMBER+1))
done
}

DB()
{
for i in `cat $DBserver`
do
VALUE=173db$DBNUM$EVT$REGION
echo -e "$CYAN pinging $i...\e[0m"
ping -c 1 $i &> /dev/null
if [ $? -gt 0 ] 
then echo -e "$RED Destination unreachable.\e[0m"
continue
fi
ssh root@$i /bin/bash << EOF
echo -e "$GREEN changing hostname of server: $i and setting it to\e[0m" "$YELLOW $VALUE\e[0m"
hostnamectl set-hostname $VALUE
EOF
DBNUM=$((DBNUM+1))
done
}

DMS
DB
OCS

