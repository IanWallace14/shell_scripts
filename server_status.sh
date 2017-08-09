#!/bin/bash
#Author: Ian Wallace
#Date: 7/28/17
#This is basically a replacement for nagios. will report 3 metrics whenever run.

#Usage: ./server_status.sh <computer> <metric> 
# either field can be replaced with 'all'

#tput is just to change color 

#general flow: write output of ssh to server and command to a temp file, 
#parse the file with awk and print the results 

#WARNING: for this to work well there's a couple requirements 
# 1.) you need to have the names and IP's of the servers in your /etc/hosts 
#		(for the 'allservers' to work)
# 2.) you need to have your key on all of the servers to allow checking the
#   metrics quickly. 

#TODO: make it so you can pick one or more servers
#TODO: make it so you can pick one or more metrics 
#TODO: fix so it works with less than 1G of mem 

# list of servers for the 'all' option 
# can (probably) be replaced with something like <username>@<ip>
allServers=( )

#used as sort of a main function, to call other functions as necessary 
#called at the bottom of the script 
# $2 is the second parameter, so it works out that it will always be the thing
#	being checked 
# TODO: replace this with a case? could be cleaner/better 
function main {
	if [[ $2 == 'mem' ]]; then 
		echo ""
  	tput setaf 5; echo -e "\x1b[1m $1"; tput sgr 0 
  	getMem $1 
	elif [[ $2 == 'storage' ]]; then
  	echo ""
  	tput setaf 5; echo -e "\x1b[1m $1"; tput sgr0
  	getStorage $1
	elif [[ $2 == 'uptime' ]]; then
	  echo ""
	  tput setaf 5; echo -e "\x1b[1m $1"; tput sgr0
	  getTime $1
	elif [[ $2 == 'status' ]]; then
	  echo ""
	  tput setaf 5; echo -e "\x1b[1m $1"; tput sgr0
	  getStatus $1
	elif [[ $2 == 'all' ]]; then 
	  echo ""
	  tput setaf 5; echo -e "\x1b[1m $1"; tput sgr0
	  getAll $1
	else 
	  echo 'not a valid option, mem uptime storage status are the options'
	fi
}

############ UPTIME #################################################
#gets the uptime. 
function getTime { 
	echo --------------------
	tput setaf 4; echo Uptime:; tput sgr0
	ssh -t $1 "uptime" > uptemp 2> /dev/null
	utime=$( awk 'FNR == 1 {print $2,$3,$4 }' uptemp )
	echo $utime
}

############# MEMORY ###################################################
function getMem {
  echo --------------------
  
  #Heading of section, in blue 
  tput setaf 4; echo Memory:; tput sgr0 

  #actually get the stats, write to memTemp  
  ssh -t $1 "free -mh" > memTemp 2> /dev/null 

  #parse the needed values 
  totalram=$( awk 'FNR == 2 {print $2 }' memTemp )
  freeram=$( awk 'FNR == 2 {print $7 }' memTemp )
  
  #Remove the 'G' at the end of each value 
  freeram=${freeram::-2}
  totalram=${totalram::-1}
  #echo $freeram
  #echo $totalram
  #if [ ${#freeeram} -eq 3 ]; then freeram=$(( freeram * .001 )); echo treu; fi
  #	echo $freeram
  #find percent used, and turn into 2 digit percentage 
  var=$( lua -e "print($freeram/$totalram)" )
  var=$( echo $var | cut -c3-4 )

  #if the percentage is only one digit, add a 0 to the end 
  if [ ${#var} -eq 1 ]; then var="${var}0"; fi

  #setting thresholds and changing colors accordingly 
  if [ $var -lt 35 ]; then
  	echo There is $( tput setaf 3; echo $var%; tput sgr0 )memory available 
  elif [ $var -lt 15 ]; then
  	echo There is $( tput setaf 1; echo $var%; tput sgr0 )memory available  
  else 
  	echo There is $( tput setaf 2; echo $var%; tput sgr0 )memory available 
  fi
}

############# STORAGE #######################################################
#gets the total and available disk space of the top disk in df 
function getStorage {
    echo --------------------

  tput setaf 4; echo Storage:; tput sgr0  
  ssh -t $1 "df -h" > storeTemp 2> /dev/null
  
  totalstorage=$( awk 'FNR == 2 {print $2 }' storeTemp )
  avalStorage=$( awk 'FNR == 2 {print $4 }' storeTemp )
  
  #Remove the 'G' at the end of each value 
  avalStorage=${avalStorage::-1}
  totalstorage=${totalstorage::-1}
  
  var=$( lua -e "print($avalStorage/$totalstorage)" )
  var=$( echo $var | cut -c3-4 )

  if [ $var -lt 35 ]; then
  	echo There is $( tput setaf 3; echo $var%; tput sgr0 )storage available 
  elif [ $var -lt 15 ]; then
  	echo There is $( tput setaf 1; echo $var%; tput sgr0 )storage available  
  else 
  	echo There is $( tput setaf 2; echo $var%; tput sgr0 )storage available 
  fi
} 

########### UP/DOWN ###########################################################
function getStatus { 
  echo --------------------

  tput setaf 4; echo Status:; tput sgr0  
  #send the result of a ping to $1 to a temp file 
  ping -c 1 $1 > statTemp 2> /dev/null 

  #parse that file for the first word on the second line 
  out=$( awk 'FNR == 2 {print $1 }' statTemp )
  
  #it would say host unreachable if it was down 
  if [[ $out == '64' ]]; then
  	echo host is; tput setaf 2; echo UP; tput sgr0
  else
  	echo host is; tput setaf 1; echo down; tput sgr0
  fi
}

#calls all fns
function getAll {
  getTime $1
  getMem $1
  getStorage $1
  getStatus $1
}

#a way to check if the user wants all of the servers to be checked or just one 
if [[ $1 == 'all' ]]; then 
	#if all is specified, call main with each server in the list and the second param 
	for i in "${allServers[@]}"
	do
		main $i $2
	done
elif [[ $1 == 'help' || $1 == '-help' ]]; then 
	echo "use the program by first defining a server, then something to check "
	echo "servers to check: knight bishop rook pawn wiki gambit swindle, all "
	echo "stats to check: mem, storage, uptime, all "
else 
	#otherwise, just use the singular server name 
	main $1 $2 
fi

#clean-up
#purpose of the 2> is in case there isnt a file to delete, 
#it will send the output into oblivion 
rm storeTemp 2> /dev/null 
rm memTemp 2> /dev/null
rm uptemp 2> /dev/null
rm statTemp 2> /dev/null
