#!/bin/env bash
#set -e
#set -x

c_flag=false
d_flag=false
s_flag=false
ip_values=()
ip6_values=()
if_value=""
rate_value=""
help(){
    echo "
limit download bandwidth
usage: 
    show qdisc class filter attached ifb0 and enp4s0
    ./tc.sh -s --if enp4s0  
    limit rate of send package to enp4s0 
    ./tc.sh -a --if enp4s0 --dn domainname.com,domainname2.com --ip 1.2.3.4,2.3.4.5 --ip6 2048:xx:xx:xx,2047:xx:xx:xx --rate [nk,nm,ng]    
    delte qdisc
    ./tc.sh -d --if enp4s0   "
}


options=$(getopt -o cdsh -l if:,dn:,ip:,ip6:,rate: -- "$@")
if [ $? != 0 ]; then
  help
  exit 1
fi

eval set -- "$options"

set -e
while true; do
  case "$1" in
    -c)
      c_flag=true
      shift
      ;;
    -d)
      d_flag=true
      shift
      ;;
    -s)
      s_flag=true
      shift
      ;;
    -h)
     help
     exit 0
     ;;
    --if)
      if_value=$2
      shift 2
      ;;
    --dn)
        IFS=',' read -r -a dns <<< "$2"
        for dn in "${dns[@]}";do
             ip_list=$(host "$dn"|grep address)
             for ip in $(echo "$ip_list" | grep -v IPv6 | cut -d ' ' -f4);do
                 ip_values+=($ip)
             done
             for ip6 in $(echo "$ip_list" | grep IPv6 | cut -d ' ' -f5);do
                 ip6_values+=($ip6)
             done
        done
        shift 2
        ;;
    --ip)
        IFS=',' read -r -a ips <<< "$2"
        ip_values+=${ips[@]}
        shift 2
      ;;
    --ip6)
        IFS=',' read -r -a ips <<< "$2"
        ip6_values+=${ips[@]}
        shift 2
      ;;
    --rate)
      rate_value=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "not available parameter: $1" >&2
      help
      exit 1
      ;;
  esac
done

if [ "$d_flag" = "true" ] && [ -z "$if_value" ]; then
    echo "please pass in interface parameter by --if"
    exit 1
fi

if [ "$c_flag" = "true" ]; then
    if [ -z "$if_value" ]; then
        echo "please pass in interface parameter by --if"
        exit 1
    fi

    if [ ${#ip6_values[@]} -eq 0 ]  && [ ${#ip_values[@]} -eq 0 ];then
        echo "please pass in source parameter by --ip, --ip6, --dn"
        exit 1
    fi

    if [ -z "$rate_value" ]; then
        echo "please pass in rate by --rate n[k,m,g]"
        exit 1
    fi
    
fi
echo "if_value: ${if_value}"
echo "ip_values: ${ip_values[@]}"
echo "ip6_values: ${ip6_values[@]}"
echo "rate_value: $rate_value"


if [ "${c_flag}" == "true" ]; then
	modprobe ifb numifbs=1
	ip link set dev ifb0 up
	tc qdisc add dev ${if_value} handle ffff: ingress
	tc filter add dev ${if_value} parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
	tc filter add dev ${if_value} parent ffff: protocol ipv6 u32 match u32 0 0 action mirred egress redirect dev ifb0
	tc qdisc add dev ifb0 root handle 1: htb default 1
#	tc class add dev ifb0 parent 1:0 classid 1:1 htb rate 1000mbps
	tc class add dev ifb0 parent 1:0 classid 1:10 htb rate ${rate_value}bps
    prio=0
#set -x
    for ip in ${ip_values[@]};do
        prio=$((prio+1))
	    tc filter add dev ifb0 protocol ip parent 1:0 prio $prio u32 \
            match ip src $ip  flowid 1:10
    done

    for ip6 in ${ip6_values[@]};do
        prio=$((prio+1))
	    tc filter add dev ifb0 protocol ipv6 parent 1:0 prio $prio u32 \
            match ip6 src $ip6  flowid 1:10
    done
#set +x
#	tc filter add dev ifb0 protocol ip parent 1:0 prio 2 u32 match ip dst 0.0.0.0/0 flowid 1:1
fi

if [ "${s_flag}" == "true" ]; then
tc class show dev ifb0
tc filter show dev ifb0
fi


if [ "${d_flag}" == "true" ]; then

tc qdisc del dev ${if_value} ingress
tc qdisc del dev ifb0 root
modprobe -r ifb
fi

