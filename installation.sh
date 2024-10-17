#!/bin/bash


function tar_create() {
  
  tar_file="$1-`date '+%Y%m%d_%H%M%S'`.tar"
  echo -e "\n Creating final tar file '$tar_file'"
  tar  -cvzf "$tar_file"  $1 &> /dev/null ||  (echo "Something went wrong with Tar file creation,command failed.";exit 4)
  rm -f $1
}

weka cluster host -b --no-header -o hostname|sort |uniq > hosts

cat > hw-validation.sh << EOF
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function run_cmd () {
  cmd=\$1
  cmd_summary=\$2
  echo "======================== \$cmd_summary ========================"
  echo -e "\${GREEN} Command: \$cmd \${NC}\n"
  eval \$cmd
  if [[ \$? -ne 0 ]]; then
     echo -e "\${RED} \"\$cmd\" failed \${NC}"
  fi
}

run_cmd "type lshw &> /dev/null && lshw -c system -short" "System"
run_cmd "type lshw &> /dev/null && lshw -c memory -short" "Memory"
run_cmd "type lshw &> /dev/null && lshw -c network -short" "Network"
run_cmd "type lshw &> /dev/null && lshw -c storage -short" "Storage"
run_cmd "dmidecode -t system | egrep 'Manufacturer|Product'" "Manufacturer Details"
run_cmd "lscpu | egrep 'Architecture|On-line|Thread|Core|Socket|Model|BIOS'" "Architecture Details"
run_cmd "type lshw &> /dev/null && lshw -c processor -short" "Processor Details"
run_cmd "lscpu | grep NUMA" "NUMA Details"
run_cmd "cpupower frequency-info" "Frequency Info"
run_cmd "dmidecode -t BIOS | grep Version" "BIOS Version"
run_cmd "cat /etc/os-release | egrep 'NAME|VERSION'" "OS Version"
run_cmd "uname -a | awk '{print \$3}'" "Kernel Version"
run_cmd "rpm -qa | grep kernel" "Installed Kernel Packages"
run_cmd "dmidecode -t memory | grep -i 'Configured Memory Speed:'" "Memory Details"
run_cmd "cat /proc/meminfo | grep MemTotal" "Total Memory"
run_cmd "stat -fc %T /sys/fs/cgroup" "Cgroup"
run_cmd "timedatectl status | grep 'synchronized:'" "Time Sync"
EOF

cat > nic-validation.sh << EOF
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function run_cmd () {
  cmd=\$1
  cmd_summary=\$2
  echo "======================== \$cmd_summary ========================"
  echo -e "\${GREEN} Command: \$cmd \${NC}\n"
  eval \$cmd
  if [[ \$? -ne 0 ]]; then
     echo -e "\${RED} \"\$cmd\" failed \${NC}"
  fi
}

run_cmd "type nmcli &> /dev/null && nmcli con show | awk '{print \\\$1,\\\$3,\\\$4}' |column -t" "nmcli Connections"
run_cmd "type ibstatus &> /dev/null && ibstatus | egrep 'device|state:|rate:|link_layer:'" "Infiniband Status"
run_cmd "weka local resources -C compute0 | grep -A3 'NET DEVICE'" "Weka NET DEVICE"

###Single Line makes lot of complexity so passing it normal command
echo "======================== Melanox Card details ========================"
echo -e "\${GREEN} Command: mst start ; mlxconfig -d <NIC> \${NC}\n"
type mst &> /dev/null
if [[ \$? -eq 0 ]]; then
    mst start
    for MLXDEV in /dev/mst/* ; do  mlxconfig -d \${MLXDEV} q | grep -e PCI_WR_ORDERING -e ADVANCED_PCI_SETTINGS -e  LINK_TYPE; done
fi

run_cmd "ip add show | grep mtu" "MTU Details"
run_cmd "ip rule" "Source-based Routing"
run_cmd "ip route show table all" "Routing Tables"
run_cmd "sysctl -a | egrep -w 'rp_filter|arp_filter|arp_announce|arp_ignore'" "RP Filter/ARP Announce/ARP Ignore"
run_cmd "ls -l /sys/class/iommu" "IOMMU"
run_cmd "systemctl status firewalld" "Firewall Status"
run_cmd "cat /sys/class/net/*/device/sriov_totalvfs" "SRIOV"
run_cmd "type lshw &> /dev/null && lshw -c network -businfo -short" "NIC Type"
run_cmd "lspci | grep -i ethernet" "NIC Vendor"

###Single Line makes lot of complexity so passing it normal command
echo "========================  NIC Firmware Version/Speed/Errors etc  ========================"
echo -e "\${GREEN} Command: ethtool <NIC> \${NC}\n"
nics=\$(ip -br a | awk '\$1 != "lo" {print \$1}' | paste -s -d ' ')
for nic  in \$nics
do 
  ethtool \$nic | grep -i speed 
  ethtool -i \$nic | egrep 'driver|firmware-version'
  ethtool -S \$nic | egrep 'error|discard|crc'
done

run_cmd "type ofed_info &> /dev/null && ofed_info -s" "OFED"
run_cmd "nstat -s | grep -i reverse" "Reverse Path Filter"
run_cmd "type ibstat &> /dev/null && ibstat -s | egrep 'CA|type:|ports:|version:'" "Infiniband Firmware Version"
run_cmd "type ibstatus &> /dev/null && ibstatus | egrep 'Infiniband|state:|rate:|link_layer:'" "Infiniband Speed"

EOF

cat > storage-validation.sh << EOF
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function run_cmd () {
  cmd=\$1
  cmd_summary=\$2
  echo "======================== \$cmd_summary ========================"
  echo -e "\${GREEN} Command: \$cmd \${NC}\n"
  eval \$cmd
  if [[ \$? -ne 0 ]]; then
     echo -e "\${RED} \"\$cmd\" failed \${NC}"
  fi
}

run_cmd "type lshw &> /dev/null && lshw -c storage -short" "Storage Information"
run_cmd "weka cluster drive -v" "Weka Cluster Drive Information"
run_cmd "lspci -v | grep NVM | sort" "NVMe Drives"
run_cmd "dmidecode -t slot | grep -e 'Bus Address' -e Designation" "NVMe Drive Slots"

EOF

cat > weka-general-validation.sh << EOF
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function run_cmd () {
  cmd=\$1
  cmd_summary=\$2
  echo "======================== \$cmd_summary ========================"
  echo -e "\${GREEN} Command: \$cmd \${NC}\n"
  eval \$cmd
  if [[ \$? -ne 0 ]]; then
     echo -e "\${RED} \"\$cmd\" failed \${NC}"
  fi
}

run_cmd "systemctl status weka-agent" "Weka Agent Status"
run_cmd "modinfo wekafsgw" "Weka FSGW Module"
run_cmd "modinfo wekafsio" "Weka FSIO Module"
run_cmd "weka status" "Weka Status"
run_cmd "weka version" "Weka Version"
run_cmd "weka cluster servers list" "Weka Cluster Servers"
run_cmd "weka cluster container -v -b" "Weka Containers BE"
run_cmd "weka cluster container -v -c" "Weka Containers Client"
run_cmd "weka cluster process -v -s uptime" "Weka Process Uptime"
run_cmd "weka cluster drive -v" "Weka Cluster Drives"
run_cmd "weka cluster buckets -s uptime" "Weka Cluster Buckets"
run_cmd "weka cluster container net" "Weka Cluster Interfaces"
run_cmd "weka debug net links" "Weka Cluster Links"
run_cmd "weka fs -v" "Weka FS"
run_cmd "weka fs group -v" "Weka FS Group"
run_cmd "weka debug traces status" "Weka Cluster Trace Status"
run_cmd "weka fs tier s3 -v" "Weka Cluster S3 Tiering"
run_cmd "weka alerts" "Weka Alerts"
run_cmd "weka events --severity major" "Weka Events"
run_cmd "weka local ps" "Weka Local Processes"
run_cmd "weka local resources -C drives0" "Local Drive0 Resources"
run_cmd "weka local resources -C compute0" "Local Compute0 Resources"
run_cmd "weka local resources -C frontend0" "Local Frontend0 Resources"

EOF

for i in `cat hosts`; do scp -o StrictHostKeyChecking=no hw-validation.sh $i:/tmp ; done
for i in `cat hosts`; do ssh $i chmod +x /tmp/hw-validation.sh ; done
pdsh -w ^hosts /tmp/hw-validation.sh  | dshbak -c > hw-validation.log

for i in `cat hosts`; do scp -o StrictHostKeyChecking=no nic-validation.sh $i:/tmp ; done
for i in `cat hosts`; do ssh $i chmod +x /tmp/nic-validation.sh ; done
pdsh -w ^hosts /tmp/nic-validation.sh  | dshbak -c > nic-validation.log

for i in `cat hosts`; do scp -o StrictHostKeyChecking=no weka-general-validation.sh $i:/tmp ; done
for i in `cat hosts`; do ssh $i chmod +x /tmp/weka-general-validation.sh ; done
pdsh -w ^hosts /tmp/weka-general-validation.sh  | dshbak -c > weka-general-validation.log

rm -f hw-validation.sh nic-validation.sh weka-general-validation.sh
##We only need tar results
tar_create "hw-validation.log"
tar_create  "nic-validation.log"
tar_create "weka-general-validation.log"
