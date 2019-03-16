#!/usr/bin/env bash
POSIXLY_CORRECT=yes
IFS=' '
# Help
HOW_TO_INFO=$(printf  "wana [FILTR] [PŘÍKAZ] [LOG [LOG2 [...]]")
# Filters definition
FILTER_FLAG=0
AFTER_DATE_FLAG=0
BEFORE_DATE_FLAG=0
IPADDR_FLAG=0
URI_FLAG=0
# Command flags definition
LIST_IP_FLAG=0
LIST_HOSTS_FLAG=0
LIST_URI_FLAG=0
HIST_IP_FLAG=0
HIST_LOAD_FLAG=0
COMMAND_FLAG=0
# Name of file where logs are stored
filename=

function usage () {
  echo "$HOW_TO_INFO" >&2
	exit 1
}

function print_dom () {
  while read -r line; do
    host $line | awk '{print $5}' | {
      read tested_line

      if [ "$tested_line" = "2(SERVFAIL)" ]; then
        echo $line
      elif [ "$tested_line" = "3(NXDOMAIN)" ]; then
        echo $line
      else echo $tested_line
      fi
    }
    done
}

function month_edit () {
  case $month in
    Jan) MON=01 ;;
    Feb) MON=02 ;;
    Mar) MON=03 ;;
    Apr) MON=04 ;;
    May) MON=05 ;;
    Jun) MON=06 ;;
    Jul) MON=07 ;;
    Aug) MON=08 ;;
    Sep) MON=09 ;;
    Oct) MON=10 ;;
    Nov) MON=11 ;;
    Dec) MON=12 ;;
esac
}
# With help from: https://www.linuxjournal.com/content/validating-ip-address-bash-script
function valid_ipv4 () {
    local  ip=$IPADDR
    local  stat=1
    #echo $ip | awk '{print length}'
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    if [ $stat -eq 1 ]; then
      echo "$0: Invalid format of IP address." >&2
	    exit 1
    fi
}

function valid_ipv6 () {
  if [[ $IPADDR =~ ^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$ ]]; then
    IFS=' '
  else
    echo "$0: Invalid format of IP address." >&2
    exit 1
  fi
}

function filter_ip_addr () {
  if [ $IPADDR_FLAG -eq 0 ]; then
    while read -r line; do
      echo $line
    done
    return
  fi

  echo $IPADDR | awk '{print length}' | {
  read ip_length

  if [ $ip_length -gt 7 ]; then
    if [ $ip_length -lt 16 ]; then
      valid_ipv4
    fi
  fi

  if [ $ip_length -gt 15 ]; then
    if [ $ip_length -lt 40 ]; then
      valid_ipv6
    fi
  fi
  }

  while read -r line; do
      echo $line | awk '{printf $1}' | {
        read testedip
        if [ "$testedip" = "$IPADDR" ]; then
          echo $line
        fi
      }
  done
}

function valid_date_a () {
  if [[ $AFTER_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    IFS=' '
  else
    echo "$0: Invalid format of date in -a switch." >&2
    exit 1
  fi
}

function filter_after_date () {

  if [ $AFTER_DATE_FLAG -eq 0 ]; then
    while read -r line; do
      echo $line
    done
    return
  fi

  valid_date_a
  while read -r line; do
      echo $line | awk '{printf $4}' | {
        read testeddate
        actualdate=${testeddate:8:4}
        month=${testeddate:4:3}
        month_edit
        actualdate+=$MON
        actualdate+=${testeddate:1:2}
        actualdate+=${testeddate:13:2}
        actualdate+=${testeddate:16:2}
        actualdate+=${testeddate:19:2}
      if [ "${AFTER_DATE//[-: ]/}" \< "$actualdate" ]; then
        echo $line
      fi
      }
  done
}

function valid_date_b () {
  if [[ $BEFORE_DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    IFS=' '
  else
    echo "$0: Invalid format of date in -b switch." >&2
    exit 1
  fi
}

function filter_before_date () {
  if [ $BEFORE_DATE_FLAG -eq 0 ]; then
    while read -r line; do
      echo $line
    done
    return
  fi

  valid_date_b
  while read -r line; do
      echo $line | awk '{printf $4}' | {
        read testeddate
        actualdate=${testeddate:8:4}
        month=${testeddate:4:3}
        month_edit
        actualdate+=$MON
        actualdate+=${testeddate:1:2}
        actualdate+=${testeddate:13:2}
        actualdate+=${testeddate:16:2}
        actualdate+=${testeddate:19:2}
      if [ "${BEFORE_DATE//[-: ]/}" \> "$actualdate" ]; then
        echo $line
      fi
      }
  done
}

function filter_uri () {
  if [ $URI_FLAG -eq 0 ]; then
    while read -r line; do
      echo $line
    done
    return
  fi

  edUri="^"
  edUri+=$URI
  while read -r line; do
    echo $line | awk '{printf $7}' | {
      read testeduri
      if [[ $testeduri =~ $edUri ]]; then
        echo $line
      fi
    }
  done
}

function list_uri_edit () {
  while read -r line; do
    if [[ $line =~ ^/ ]]; then
      echo $line
    fi
  done
}

function hist_ip_creator () {
  sort -n -r | {
  while read -r line; do
    echo $line | awk '{printf $1}' | {
      read nmbs
      hash_nmb=
      for (( i = 0; i < $nmbs; i++ )); do
        hash_nmb+="#"
      done

      echo $line | awk '{print $2}' | {
        read act_ip
        printf "%s (%d): %s\n" "$act_ip" "$nmbs" "$hash_nmb"
      }
  }
  done
  }
}

function hist_load_creator () {
  awk '{print $4}' | sort | uniq -c
}

# Getting values of filters
while getopts "a:b:i:u:" arg; do
  ((ind_arg=$OPTIND-1))

  case $arg in
    a)              AFTER_DATE=$OPTARG
                    AFTER_DATE_FLAG=1
                    FILTER_FLAG=1
                    shift
                    AFTER_DATE+=" ${!ind_arg}"
                  ;;
    b)              BEFORE_DATE=$OPTARG
                    BEFORE_DATE_FLAG=1
                    FILTER_FLAG=1
                    shift
                    BEFORE_DATE+=" ${!ind_arg}"
                  ;;
    i)            if [ ${!ind_arg} = "-ip" ]; then
                    IPADDR=${!OPTIND}
                    IPADDR_FLAG=1
                    FILTER_FLAG=1
                    ((OPTIND++))
                  else
                    usage
                  fi
                  ;;
    u)            if [ ${!ind_arg} = "-uri" ]; then
                    URI=${!OPTIND}
                    URI_FLAG=1
                    FILTER_FLAG=1
                    ((OPTIND++))
                  else
                    usage
                  fi
                  ;;
    *)            usage
                  ;;
  esac
done

((OPTIND--))
shift $OPTIND

# Finding out which command will be executed [just 1 of em]
case $1 in
    list-ip )               LIST_IP_FLAG=1
                            COMMAND_FLAG=1
                            ;;
    list-hosts )            LIST_HOSTS_FLAG=1
                            COMMAND_FLAG=1
                            ;;
    list-uri )              LIST_URI_FLAG=1
                            COMMAND_FLAG=1
                            ;;
    hist-ip )               HIST_IP_FLAG=1
                            COMMAND_FLAG=1
                            ;;
    hist-load )             HIST_LOAD_FLAG=1
                            COMMAND_FLAG=1
                            ;;
esac

# If a command was set, shifting
if [ $COMMAND_FLAG -eq 1 ]; then
    shift
fi

# Reading from stdin when no log files are available
if [ "$1" = "" ]; then
    echo "cus" >&1
fi

# Pre vsetky subory
while [ "$1" != "" ]; do
    filename=$1

    # Case when file does not exist
    if [ ! -f $filename ]; then
      echo "$0: File '$filename' does not exist." >&2
	    exit 1
    fi

    if [ ! -r $filename ]; then
      echo "$0: File '$filename' is not readable." >&2
      exit 1
    fi

    if [ $COMMAND_FLAG -eq 0 ]; then
      # Case when neither filter nor command is set
      if [ $FILTER_FLAG -eq 0 ]; then
        if [ ${filename: -3} == ".gz" ]; then
          zcat $filename >&1
        else
          cat $filename
        fi
      fi

      if [ ${filename: -3} == ".gz" ]; then
        gunzip -c $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date
      else
        cat $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date
      fi
    fi

    if [ $LIST_IP_FLAG -eq 1 ]; then
      if [ ${filename: -3} == ".gz" ]; then
        gunzip -c $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $1}'
      fi
      cat $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $1}'
    fi

    if [ $LIST_HOSTS_FLAG -eq 1 ]; then
      if [ ${filename: -3} == ".gz" ]; then
        gunzip -c $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $1}' | print_dom
      fi
      cat $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $1}' | print_dom
    fi

    if [ $LIST_URI_FLAG -eq 1 ]; then
      if [ ${filename: -3} == ".gz" ]; then
        gunzip -c $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $7}' | list_uri_edit
      fi
      cat $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $7}' | list_uri_edit
    fi

    if [ $HIST_IP_FLAG -eq 1 ]; then
      if [ ${filename: -3} == ".gz" ]; then
        gunzip -c $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $1}' | sort -n -r | uniq -c | hist_ip_creator
      fi
      cat $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | awk '{print $1}' | sort -n -r | uniq -c | hist_ip_creator
    fi

    if [  $HIST_LOAD_FLAG -eq 1 ]; then
      cat $filename | filter_ip_addr | filter_before_date | filter_uri | filter_after_date | hist_load_creator
    fi
    shift
done

exit 0