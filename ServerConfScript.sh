#! /bin/bash  

FILEPATH=/home/sigvalue
FOLDER=postscript_server
DMSFILE=DMSfileshare.cred
DBFILE=DBfileshare.cred
OCSFILE=OCSfileshare.cred
RESOLV=/etc/resolv.conf
REGISTRY=$FILEPATH/registry/ro.reg
ORAPATH=/oracle/app/oracle/product/19.0.0/dbhome_1/network/admin
file=/etc/ssh/sshd_config
grfile=/etc/default/grub
TODAY=`date +'%Y%m%d'`
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
CYAN="\e[96m"

echo -e "$GREEN To change DB server in registry, press\e[0m $YELLOW 1!\e[0m"
echo -e "$GREEN To change DNS in resolve.conf, press\e[0m $YELLOW 2!\e[0m"
echo -e "$GREEN To change DMS servers in registry, press\e[0m $YELLOW 3!\e[0m"
echo -e "$GREEN To create the mounts, press\e[0m $YELLOW 4!\e[0m"
echo -e "$GREEN To make NTP changes, press\e[0m $YELLOW 5!\e[0m"
echo -e "$GREEN To disable root ssh, press\e[0m $YELLOW 6!\e[0m"
echo -e "$GREEN To enable Azure Serial Console, press\e[0m $YELLOW 7!\e[0m"
echo -e "$GREEN To make all the changes in one go, press\e[0m $YELLOW 8!\e[0m"
read  input

function REGCOPY()
{
   cp $REGISTRY $FILEPATH/registry/ro_$TODAY.reg
   chmod 666 $FILEPATH/registry/ro_$TODAY.reg
   chown sigvalue:sigvalue $FILEPATH/registry/ro_$TODAY.reg
}


function FILETRANSFER()
{
for i in `cat $FILEPATH/automation/$FOLDER/OCserver.txt` `cat $FILEPATH/automation/$FOLDER/DMserver.txt`
  do
    echo -e "$CYAN Transferring ro.reg to:\e[0m" "$RED $i\e[0m"
    scp -q /home/sigvalue/registry/ro.reg root@$i:$FILEPATH/registry
  done
}



function DBREGISTRY()

{
  ################################################################
  #          Change the DB server details in registry            #
  ################################################################

 
  read  -p "enter the new DB server IP/host: " newDB
  if [ -z "$newDB" ]; then
      echo -e "$YELLOW DB server IP/host not provided.\e[0m"
  else
  echo -e "$YELLOW ################# Step 1 Start ################\e[0m"
  REGCOPY
  oldDB=`cat $REGISTRY | grep -w "DBServer" | head -1`
  oldDB=${oldDB:11}
  newDB=`echo $newDB | awk '{print "\x22" $1 "\x22"}'`
  sed -i "s/$oldDB/$newDB/g" $REGISTRY
  echo -e "$GREEN registry updated to use $newDB from $oldDB\e[0m"
  chmod 666 $REGISTRY
  for i in `cat $FILEPATH/automation/postscript_server/DBserver.txt`
   do 
    ssh root@$i /bin/bash << EOF
    cp $ORAPATH/tnsnames.ora $ORAPATH/tnsnames_$TODAY.ora
    cp $ORAPATH/listener.ora $ORAPATH/listener_$TODAY.ora
    chmod 644 $ORAPATH/tnsnames_$TODAY.ora
    chmod 644 $ORAPATH/listener_$TODAY.ora
    chown oracle:oinstall $ORAPATH/tnsnames_$TODAY.ora
    chown oracle:oinstall $ORAPATH/listener_$TODAY.ora
    listvar=\`cat $ORAPATH/listener.ora | grep -w 'HOST'\`
    var1=\`echo \$listvar | grep -oP '(?<=HOST = ).[^)]*'\`
    sed -i "s/\$var1/$newDB/gi" $ORAPATH/tnsnames.ora
    temp=\`cat $ORAPATH/tnsnames.ora | grep $newDB | wc -c\`
    if [ \$temp -gt 0 ]; then
       echo -e "$GREEN tnsnames.ora updated at\e[0m" "$RED $i\e[0m"
       else echo -e "$RED tnsnames.ora could not be updated at $i\e[0m"
    fi
    sed -i "s/\$var1/$newDB/gi" $ORAPATH/listener.ora
    temp=\`cat $ORAPATH/listener.ora | grep $newDB | wc -c\`
    if [ \$temp -gt 0 ]; then
      echo -e "$GREEN listener.ora updated at\e[0m" "$RED $i\e[0m"
      else echo -e "$RED listener.ora could not be updated at $i\e[0m"
    fi
EOF
   done

 FILETRANSFER

  var=`cat /etc/ssh/ssh_config | grep -w 'Host' | tail -1`
  sshvar=${var:5}
  newDB=`echo $newDB | grep -oP '(?<=").[^"]*'`
  sed -i "s/$sshvar/$newDB/g" /etc/ssh/ssh_config
  for i in `cat $FILEPATH/automation/$FOLDER/OCserver.txt` `cat $FILEPATH/automation/$FOLDER/DMserver.txt`
   do 
    ssh root@$i /bin/bash << EOF
    sed -i "s/$sshvar/$newDB/g" /etc/ssh/ssh_config
    if [ $? -eq 0 ]; then 
      echo -e "$GREEN ssh_config file updated at\e[0m" "$RED $i\e[0m"
      else echo -e "$RED ssh_config file could not be updated at $i\e[0m"
    fi
EOF
   done
  echo -e "$YELLOW ################# Step 1 End ################\e[0m"
  fi
}



function RESOLVCONF()

{
  ################################################################
  #           Add new DNS in the /etc/resolv.conf                #
  ################################################################
  
  LENGTH=`lsattr $RESOLV | grep -w 'i'| wc -c`
  read -p "enter the DNS value:" newDNS
  if [ -z "$newDNS" ];  then
      echo -e "$YELLOW Domain Name Server not provided.\e[0m"
  else
     if [ $LENGTH -gt 0 ]; then
     echo -e "$YELLOW ################# Step 2 Start ################\e[0m"
           chattr -i $RESOLV
     fi
      sed -i "/search/s/$/ $newDNS/g" $RESOLV
  for i in `cat $FILEPATH/automation/$FOLDER/servers.txt`
   do
    echo -e "$CYAN sending resolv.conf to:\e[0m" "$RED $i\e[0m"
    scp -q $RESOLV root@$i:/etc 
    if [ $? -ne 0 ]; then
       echo -e "$RED Could not transfer resolv.conf to $i\e[0m"
    fi
    ssh root@$i /bin/bash << EOF
    chattr +i $RESOLV
EOF
  done
      chattr +i $RESOLV
  echo -e "$YELLOW ################# Step 2 End ################\e[0m"
  fi
}


function SERVERREGISTRY()

{
  ################################################################
  #          Change the DMS server details in registry           #
  ################################################################
  
  read -p "enter the new DMS01 server IP/host:" newDM01
  if [ -z "$newDM01" ]; then
      echo -e "$RED DMS01 hostname cannot be blank please rerun the script with correct inputs.\e[0m"
      exit 1
  else  
     echo -e "$YELLOW ################# Step 3 Start ################\e[0m"
     REGCOPY
     varDMS=`cat $REGISTRY | grep '@="1' | head -1`
     varDMS=${varDMS:2}
     newDM01=`echo $newDM01 | awk '{print "\x22" $1 "\x22"}'`
     sed -i "s/$varDMS/$newDM01/g" $REGISTRY
     echo -e "$GREEN registry updated to use $newDM01 from $varDMS\e[0m"
  
############ make changes as per dms02 server #############

  read -p "enter the new DMS02 server IP/host:" newDM02
  if [ -z "$newDM02" ]; then 
       echo -e "$YELLOW DMS02 IP/host not provided, proceeding to DMS03.\e[0m"
  else
       varDMS=`cat $REGISTRY | grep -w "Server2" | head -1`
       varDMS=${varDMS:10}
       newDM02=`echo $newDM02 | awk '{print "\x22" $1 "\x22"}'`
       sed -i "s/$varDMS/$newDM02/g" $REGISTRY
       echo -e "$GREEN registry updated to use $newDM02 from $varDMS\e[0m"
  fi

########### make changes as per DMS03 server ############

  read -p "enter the new DMS03 server IP/host:" newDM03
  if [ -z "$newDM03" ]; then
       echo -e "$YELLOW DMS03 IP/host not provided, proceeding to DMS04.\e[0m"
  else
       varDMS=`cat $REGISTRY | grep -w "Server3" | head -1`
       varDMS=${varDMS:10}
       newDM03=`echo $newDM03 | awk '{print "\x22" $1 "\x22"}'`
       sed -i "s/$varDMS/$newDM03/g" $REGISTRY
       echo -e "$GREEN registry updated to use $newDM03 from $varDMS\e[0m"
  fi

######### make changes as per DMS04 server ############

  read -p "enter the new DMS04 server IP/host:" newDM04
  if [ -z "$newDM04" ]; then
       echo -e "$YELLOW DMS04 IP/host not provided, no updates will be made.\e[0m"
  else
       varDMS=`cat $REGISTRY | grep -w "Server4" | head -1`
       varDMS=${varDMS:10}
       newDM04=`echo $newDM04 | awk '{print "\x22" $1 "\x22"}'`
       sed -i "s/$varDMS/$newDM04/g" $REGISTRY
       echo -e "$GREEN registry updated to use $newDM04 from $varDMS\e[0m"
  fi

  chmod 666 $REGISTRY
  FILETRANSFER
  echo -e "$YELLOW ################# Step 3 End ################\e[0m"
 fi
}

function CREDENTIALS()

{
read -p "enter the user name for FILE SHARE:" user
read -p "enter the password for the FILE SHARE:" paswd
read -p "enter the FS path for the FILE SHARE:" fs
if [ -z "$user" ] || [ -z "$paswd" ] || [ -z "$fs" ]; then
       echo -e "$RED None of FS user, password, path can be blank. Please rerun the script with correct inputs..\e[0m"
       exit 1
else
echo -e "$YELLOW ################# Step 4 Start ################\e[0m"
var1=`cat $FILEPATH/automation/$FOLDER/credentials.cred | grep -w 'username'`
var2=`echo $var1 | grep -oP '(?<==).[^"]*'`
sed -i "s.$var2.$user.g" $FILEPATH/automation/$FOLDER/credentials.cred
var1=`cat $FILEPATH/automation/$FOLDER/credentials.cred | grep -w 'password'`
var2=`echo $var1 | grep -oP '(?<==).[^"]*'`
sed -i "s.$var2.$paswd.g" $FILEPATH/automation/$FOLDER/credentials.cred
var1=`cat $FILEPATH/automation/$FOLDER/$DMSFILE | grep -w bash | head -1 `
var2=`echo $var1 | grep -oP '(?<=//).[^/]*'`
sed -i "s,$var2,$fs,g" $FILEPATH/automation/$FOLDER/$DMSFILE
sed -i "s,$var2,$fs,g" $FILEPATH/automation/$FOLDER/$OCSFILE
sed -i "s,$var2,$fs,g" $FILEPATH/automation/$FOLDER/$DBFILE
chmod 700 $FILEPATH/automation/$FOLDER/credentials.cred && (exec "$FILEPATH/automation/$FOLDER/credentials.cred")
for i in `cat $FILEPATH/automation/$FOLDER/servers.txt`
do
scp -q $FILEPATH/automation/$FOLDER/credentials.cred root@$i:$FILEPATH/
ssh root@$i /bin/bash << EOF
exec "$FILEPATH/credentials.cred"
EOF
done
fi
}

function FILESHARE()
{

 ###########################################################
 #     Distribute smb fs file/create mounts/modify fstab   #
 ###########################################################


   if [ -s $DMSFILE ]; then
      echo -e "$GREEN running DMS mount file.\e[0m"
       chmod 700 $FILEPATH/automation/$FOLDER/$DMSFILE && (exec "$FILEPATH/automation/$FOLDER/$DMSFILE")
       for i in `cat $FILEPATH/automation/$FOLDER/DMserver.txt`
         do
           echo -e "$CYAN sending DMS mounts file to:\e[0m" "$RED $i\e[0m"
           scp -q $FILEPATH/automation/$FOLDER/$DMSFILE root@$i:$FILEPATH/
           ssh root@$i /bin/bash << EOF 
           exec "$FILEPATH/$DMSFILE"

EOF
        done
  else  echo -e "$YELLOW Skipping DMS mount file since it's empty!\e[0m" 
  fi

  if [ -s $OCSFILE ]; then
       echo -e "$GREEN running OCS mount file.\e[0m"
       chmod 700 $FILEPATH/automation/$FOLDER/$OCSFILE
       for i in `cat $FILEPATH/automation/$FOLDER/OCserver.txt`
         do
           echo -e "$CYAN sending OCS mounts file to:\e[0m" "$RED $i\e[0m"
           scp -q $FILEPATH/automation/$FOLDER/$OCSFILE root@$i:$FILEPATH/
           ssh root@$i /bin/bash << EOF
           exec "$FILEPATH/$OCSFILE"
EOF
         done
  else echo -e "$YELLOW Skipping OCS mount file since it's empty!\e[0m"
   fi

  if [ -s $DBFILE ]; then
      echo -e "$GREEN running DB mount file.\e[0m"
      chmod 700 $FILEPATH/automation/$FOLDER/$DBFILE
      for i in `cat $FILEPATH/automation/$FOLDER/DBserver.txt`
        do
          echo -e "$CYAN sending DB mounts file to:\e[0m" "$RED $i\e[0m"
          scp -q $FILEPATH/automation/$FOLDER/$DBFILE root@$i:$FILEPATH/
          ssh root@$i /bin/bash << EOF
          exec "$FILEPATH/$DBFILE"
EOF
        done
   else echo -e "$YELLOW Skipping DB file since it's empty!\e[0m" 
   fi
echo -e "$YELLOW ################# Step 4 End ################\e[0m"

}


function NTPfunc 
{

read  -p "enter the NTP1 IP:" ntpIP
if [ -z "$ntpIP" ]; then 
   echo -e "$YELLOW NTP1 IP cannot be blank.\e[0m"
else
read -p "enter the NTP2 IP:" ntpIP2
if [ -z "$ntpIP2" ]; then 
   echo -e "$YELLOW NTP2 IP not provided.\e[0m"
fi
echo -e "$YELLOW ################# Step 5 Start ###############\e[0m"
chronvar=`cat /etc/chrony.conf | grep 'iburst' | tail -1`
varntpIP=`echo server $ntpIP iburst`
varntpIP2=`echo server $ntpIP2 iburst`
sed -i "/$chronvar/a $varntpIP" /etc/chrony.conf
sed -i "/$chronvar/a $varntpIP2" /etc/chrony.conf
service chronyd restart
 for i in `cat $FILEPATH/automation/$FOLDER/servers.txt`
  do 
   ssh root@$i /bin/bash << EOF
   chrony=\`cat /etc/chrony.conf | grep 'iburst' | tail -1\`
   sed -i "/\$chrony/a $varntpIP" /etc/chrony.conf
   sed -i "/\$chrony/a $varntpIP2" /etc/chrony.conf
  if [ $? -eq 0 ]; then
     echo -e "$GREEN chrony updated to use new NTP server at: $i \e[0m"
    else
      echo -e "$RED chrony could not be updated at: $i \e[0m"
   fi

   service chronyd restart
EOF
  done
echo -e "$YELLOW ################# Step 5 End ##################\e[0m"
fi
}


function DISABLEROOT()

{

echo -e "$YELLOW ################# Step 6 Start ##################\e[0m"

rootlen=`grep '#PermitRootLogin' $file| wc -c`
cp $file $file_$DATE
rootawk=`grep  '#PermitRootLogin' $file| awk '{print $2}'`
if [ $rootlen -gt 0 ]; then
  if [ $rootawk == 'yes' ]; then
   sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' $file
   service sshd restart
  fi
else
echo PermitRootLogin no >> $file
service sshd restart
for i in `cat servers.txt`
do
echo -e "$CYAN Transferring $file at: $i \e[0m"
scp -q $file root@$i:/etc/ssh/
ssh root@$i /bin/bash << EOF
service sshd restart
EOF
done
fi

echo -e "$YELLOW ################# Step 6 End ##################\e[0m"

}
   
function AZURESC()

{

echo -e "$YELLOW ################# Step 7 Start ##################\e[0m"

rhlen=`grep "rhgb quiet" $grfile | wc -c`
if [ $rhlen -gt 0 ]; then
sed -i 's/ rhgb quiet//g' $grfile 
fi
del=`grep 'rootdelay' $grfile| wc -c`
if [ $del -eq 0 ]; then
echo "console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300" >> $grfile
systemctl enable serial-getty@ttyS0.service > /dev/null
sleep 1
systemctl start serial-getty@ttyS0.service
echo -e "$GREEN $grfile updated! \e[0m"
for i in `cat servers.txt`
do
echo -e "$CYAN Transferring GRUB file to: $i \e[0m"
scp -q $grfile root@$i:/etc/default/
ssh root@$i << EOF
systemctl enable serial-getty@ttyS0.service > /dev/null
sleep 1
systemctl start serial-getty@ttyS0.service
EOF
done
fi
echo -e "$YELLOW ################# Step 7 End ##################\e[0m"

}



   cat $FILEPATH/automation/$FOLDER/OCserver.txt > $FILEPATH/automation/$FOLDER/servers.txt
   echo >> $FILEPATH/automation/$FOLDER/servers.txt
   cat $FILEPATH/automation/$FOLDER/DMserver.txt >> $FILEPATH/automation/$FOLDER/servers.txt
   echo >> $FILEPATH/automation/$FOLDER/servers.txt
   cat $FILEPATH/automation/$FOLDER/DBserver.txt >> $FILEPATH/automation/$FOLDER/servers.txt
   sed -i "/^$/d" $FILEPATH/automation/$FOLDER/servers.txt


if [ $input == 1 ]; then
     DBREGISTRY

elif [ $input == 2 ]; then
     RESOLVCONF

elif [ $input == 3 ]; then
     SERVERREGISTRY
elif [ $input == 4 ]; then
     CREDENTIALS
     FILESHARE 
elif [ $input == 5 ]; then
      NTPfunc
elif [ $input == 6 ]; then
      DISABLEROOT  
elif [ $input == 7 ]; then
      AZURESC
elif  [ $input == 8 ]; then 
     DBREGISTRY
     RESOLVCONF
     SERVERREGISTRY
     CREDENTIALS
     FILESHARE
     NTPfunc
     DISABLEROOT
else echo -e "$RED Invalid Input. Please rerun the script with correct options.\e[0m"
  
fi
