# DB2 setup

## configure the nodes, and setup DB2 pureScale

NB: this was not translated to a proper bash script yet.
For now, you have to copy and paste this code to your terminal.

please execute `private.sh` before this script in order to setup variables

```bash
# then connect to d1:
scp $localgithubfolder/start_network.sh rhel@$jumpbox:~/
ssh rhel@$jumpbox
ssh -o StrictHostKeyChecking=no 192.168.1.20
sudo su

ssh-keygen -t dsa -f /root/.ssh/id_dsa -q -N ""
cp /root/.ssh/id_dsa.pub /home/rhel/root_id_dsa.pub

#back to the jumbox
exit # exit from sudo su
exit # exit from 192.168.1.20

scp rhel@192.168.1.20:/home/rhel/root_id_dsa.pub .
```

TODO - this has to be done on all nodes d1 (for what has not already been done), d2 to d4, cf1 and cf2

{all_db2_nodes{

```bash
nodeip=192.168.1.20 # and also 192.168.1.21, 192.168.1.40 and 192.168.1.41

scp -o StrictHostKeyChecking=no root_id_dsa.pub rhel@$nodeip:~/
scp start_network.sh rhel@$nodeip:~/
ssh $nodeip
sudo su
if [ `hostname` != "d1" ]
then
    mkdir ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    cat /home/rhel/root_id_dsa.pub >> /root/.ssh/authorized_keys
fi

# cf https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/t0055342.html?pos=3
cat >> /etc/ssh/sshd_config << EOF

PermitRootLogin yes
EOF

db2bits='https://###obfuscated###.blob.core.windows.net/setup/v11.1_linuxx64_server_t.tar.gz?sv=2016-05-31###obfuscated###2FGtJ6Q%3D'
mkdir /data2
cd /data2
mkdir db2bits/
cd db2bits/
curl -o v11.1_linuxx64_server_t.tar.gz "$db2bits"
tar xzvf v11.1_linuxx64_server_t.tar.gz

source /home/rhel/start_network.sh

#cat << EOF >> /etc/ssh/ssh_config 
#Port 22
#Protocol 2,1
#EOF

systemctl stop firewalld
systemctl disable firewalld
systemctl status firewalld
# TODO: update firewall instead of disabling it - For now, the following is not sufficient:
# cf <https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/r0061630.html?pos=2>
#firewall-cmd --add-port=56000/tcp --permanent
#firewall-cmd --add-port=56001/tcp --permanent
#firewall-cmd --add-port=50000/tcp --permanent
#firewall-cmd --add-port=60000-60005/tcp --permanent
#firewall-cmd --add-port=1191/tcp --permanent
#firewall-cmd --add-port=12347/udp --permanent
#firewall-cmd --add-port=12348/udp --permanent
#firewall-cmd --add-port=657/udp --permanent
#firewall-cmd --reload

# install pre-requisistes
#yum update --releasever=7.3 # TODO: test this - return HTTP 404...
# DO NOT USE yum update -y
# TODO: TEST it actually installs everything while executing only once
yum install -y \
    binutils \
    binutils-devel \
    compat-libstdc++-33.i686 \
    compat-libstdc++-33.x86_64 \
    cpp \
    dapl \
    device-mapper-multipath.x86_64 \
    file \
    gcc \
    gcc-c++ \
    glibc \
    ibacm \
    ibutils \
    iscsi-initiator-utils \
    kernel-devel-3.10.0-514.el7.x86_64 \
    kernel-headers-3.10.0-514.el7.x86_64 \
    ksh \
    libcxgb3 \
    libgcc \
    libgomp \
    libibcm \
    libibmad \
    libibverbs \
    libipathverbs \
    libmlx4 \
    libmlx5 \
    libmthca \
    libnes \
    librdmacm \
    libstdc++ \
    libstdc++*.i686 \
    m4 \
    make \
    ntp \
    ntpdate \
    numactl \
    openssh \
    pam-devel.i686 \
    pam-devel.x86_64 \
    patch \
    perl-Sys-Syslog \
    rdma \
    rpm-build redhat-rpm-config asciidoc hmaccalc perl-ExtUtils-Embed pesign xmlto \
    sg3_utils \
    sg3_utils-libs


# force initiator for the dev environment. Should retrieve them and update the target server instead.
case `hostname` in
"d1")
cat <<EOF >/etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:c4e37143a6fa
EOF
;;
"d2")
cat <<EOF >/etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:242e56883d62
EOF
;;
"cf1")
cat <<EOF >/etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:fd582735ef35
EOF
;;
"cf2")
cat <<EOF >/etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:b58d9add7fcc
EOF
;;
esac
cat /etc/iscsi/initiatorname.iscsi

cat << EOF >> /etc/hosts 
192.168.3.20 d1
192.168.3.21 d2
192.168.3.40 cf1
192.168.3.41 cf2
192.168.1.20 d1-eth0
192.168.1.21 d2-eth0
192.168.1.40 cf1-eth0
192.168.1.41 cf2-eth0
192.168.3.20 d1-eth1
192.168.3.21 d2-eth1
192.168.3.40 cf1-eth1
192.168.3.41 cf2-eth1
192.168.4.20 d1-eth2
192.168.4.21 d2-eth2
192.168.1.30 witn0-eth0
192.168.3.60 witn1-eth1
192.168.4.60 witn1-eth2
EOF

#format data disk and mount it
#TODO: data disk may be on sdb or sdc
#dataon=sdb
dataon=sdc
printf "n\np\n1\n\n\np\nw\n" | fdisk /dev/$dataon
printf "\n" | mkfs -t ext4 /dev/${dataon}1
mkdir /data1
mount /dev/${dataon}1 /data1
if [ "$dataon" == "sdc" ]
then 
cat >> /etc/fstab << EOF
/dev/sdc1   /data1  auto    defaults,nofail 0   0
EOF
else
cat >> /etc/fstab << EOF
/dev/sdb1   /data1  auto    defaults,nofail 0   0
EOF
fi

#if [ `hostname` != "cf1" ] && [ `hostname` != "cf1" ]
#then # {connect to iscsi{
# setup multipath.conf 
cat << EOF > /etc/multipath.conf 
defaults { 
    user_friendly_names no
    bindings_file /etc/multipath/bindings4db2
    max_fds max
    flush_on_last_del yes 
    queue_without_daemon no 
    dev_loss_tmo infinity
    fast_io_fail_tmo 5
} 
blacklist { 
    wwid "SAdaptec*" 
    devnode "^hd[a-z]" 
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*" 
    devnode "^sda[0-9]*" 
    devnode "^sdb[0-9]*" 
    devnode "^sdc[0-9]*" 
    devnode "^cciss.*" 
} 
multipaths {
    multipath {
        wwid  36001405149ee39c319845aaa710099a7
        alias db2data1  
    }
    multipath {
        wwid  36001405bfc71ff861174f2bbb0bfea37
        alias db2log1  
    }
    multipath {
        wwid  36001405484ba6ab80934f2290a2b579f
        alias db2shared
    }
    multipath {
        wwid  36001405645b2e72c56142ef97932cb95
        alias db2tieb 
    }
    multipath {
        wwid  360003ff44dc75adc8a833f5e2a000a50
        alias w1db2data1  
    }
    multipath {
        wwid  360003ff44dc75adc8f92b0dced7e4886
        alias w1db2log1  
    }
    multipath {
        wwid  360003ff44dc75adcba4d5eac89852c53
        alias w1db2shared
    }
    multipath {
        wwid  360003ff44dc75adcbaee3c293e0a909e
        alias w1db2tieb 
    }
}
EOF

modprobe dm-multipath 
service multipathd start 
chkconfig multipathd on
multipath -l
#iscsiadm -m discovery -t sendtargets -p 192.168.1.10
iscsiadm -m discovery -t sendtargets -p 192.168.1.30
iscsiadm -m node -L automatic 
# TODO: a timeout happens on an IP V6 address for w1 iSCSI target, no consequence
iscsiadm -m session 
multipath -l
fdisk -l | grep /dev/mapper/3
lsblk #inconsistent paths frmo one machine to another
sleep 0.5s
ll /dev/mapper

#fi # }connect to iscsi}

#https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/t0055374.html?pos=2
groupadd --gid 341 db2iadm1
groupadd --gid 342 db2fadm1
useradd -g db2iadm1 -m -d /home/db2sdin1 db2sdin1
useradd -g db2fadm1 -m -d /home/db2sdfe1 db2sdfe1

mkdir -p /var/ct/cfg/
# define the witness. cf https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/t0061581.html
cat <<EOF > /var/ct/cfg/netmon.cf
!IBQPORTONLY !ALL
!REQD eth0 192.168.1.30
!REQD eth1 192.168.3.60
EOF

nbnics=`ls -als /sys/class/net/  | grep eth | wc -l`
if [ $nbnics == 3 ]
then
cat <<EOF >> /var/ct/cfg/netmon.cf
!REQD eth2 192.168.4.60
EOF
fi
cat /var/ct/cfg/netmon.cf

# this was developed with `uname -r` returning `3.10.0-514.28.1.el7.x86_64` before reboot
uname -r
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
#TODO: check third entry is kernel 514, maybe not yum install kernel will avoid this
# Red Hat Enterprise Linux Server (3.10.0-514.el7.x86_64) 7.3 (Maipo)
# please do **not** point to Red Hat Enterprise Linux Server (3.10.0-514.28.1.el7.x86_64) 7.3 (Maipo)
grub2-set-default 'Red Hat Enterprise Linux Server (3.10.0-514.el7.x86_64) 7.3 (Maipo)'
cat /boot/grub2/grubenv |grep saved
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

## this was developed with `uname -r` returning `3.10.0-514.28.1.el7.x86_64` before reboot
#uname -r
#ls -als /lib/modules/`uname -r`/
##yum install -y ftp://mirror.switch.ch/pool/4/mirror/scientificlinux/7.1/x86_64/updates/security/kernel-devel-3.10.0-514.el7.x86_64.rpm
#rm -f /lib/modules/3.10.0-514.28.1.el7.x86_64/build
#ln -s /usr/src/kernels/3.10.0-514.el7.x86_64 /lib/modules/3.10.0-514.28.1.el7.x86_64/build
#ll /lib/modules/
#ls -als /lib/modules/`uname -r`/

sestatus
sed -i s/SELINUX=enforcing/SELINUX=disabled/ /etc/selinux/config
setenforce 0
sestatus

reboot
### wait for reboot and reconnect

#ssh $nodeip
#sudo su
#
#yum install -y rpm-build redhat-rpm-config asciidoc hmaccalc perl-ExtUtils-Embed pesign xmlto
#cd /usr/lpp/mmfs/src
##mv config/env.mcr config/env.mcr.old
#make Autoconfig
#make World
#make InstallImages
#ll /usr/lpp/mmfs/src/bin/lxtrace*
#ll /usr/lpp/mmfs/src/bin/kdump*
#make rpm
#ll /root/rpmbuild/RPMS/x86_64/gpfs*

#exit
#exit
# back to jumpbox
```
}all_db2_nodes}

```bash
ssh 192.168.1.20
sudo su

cat <<EOF >~/.ssh/config
Host *
    StrictHostKeyChecking no
EOF
chmod 400 ~/.ssh/config

cat /root/.ssh/id_dsa.pub >> /root/.ssh/authorized_keys
scp /root/.ssh/id_dsa d2:/root/.ssh
scp /root/.ssh/id_dsa cf1:/root/.ssh
scp /root/.ssh/id_dsa cf2:/root/.ssh
scp /root/.ssh/config d2:/root/.ssh
scp /root/.ssh/config cf1:/root/.ssh
scp /root/.ssh/config cf2:/root/.ssh

# if you don't have a response file, you might want to see *First install with GUI, generate a response file* in the Appendix of this document.

# TODO: automate the following, starting from the db2server.rsp in this repo.
ll /dev/mapper
vi /root/db2server.rsp
# take the 
# update based on ll /dev/mapper on d1
# see <http://www-01.ibm.com/support/docview.wss?uid=swg21969333>
# TODO: automate

tentativenum=180412b
/data2/db2bits/server_t/db2setup -r /root/db2server.rsp -l /tmp/db2setup_${tentativenum}.log -t /tmp/db2setup_${tentativenum}.trc
```

the last step may fail with warnings. We need at least the bits in /data1/db2.

## Compile GPL, Create DB2 database, connect to it from a client

{on the 4 nodes{
```
cd /usr/lpp/mmfs/src
#mv config/env.mcr config/env.mcr.old
make Autoconfig
make World
make InstallImages

/data1/db2/bin/db2cluster -cfs -list -filesystem

```
}on the 4 nodes}


```bash
ssh rhel@$jumpbox
ssh 192.168.1.20
sudo su

# https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/t0006744.html
# https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.admin.cmd.doc/doc/r0002057.html
ll /dev/mapper

#sample result: 
#crw------- 1 root root 10, 236 Apr 13 06:29 control
#lrwxrwxrwx 1 root root       7 Apr 13 07:04 w1db2data1 -> ../dm-2
#lrwxrwxrwx 1 root root       7 Apr 13 07:10 w1db2log1 -> ../dm-3
#lrwxrwxrwx 1 root root       7 Apr 13 06:29 w1db2shared -> ../dm-1
#lrwxrwxrwx 1 root root       7 Apr 13 06:29 w1db2tieb -> ../dm-0

/data1/db2/instance/db2icrt -d -cf cf1 -cfnet cf1 -cf cf2 -cfnet cf2 -m d1 -mnet d1 -m d2 -mnet d2 -instance_shared_dev /dev/dm-2 -tbdev /dev/dm-0 -u db2sdfe1 db2sdin1
```

## Appendix

### First install with GUI, generate a response file

```bash
yum group install -y "Server with GUI"
#check if the following lines are needed
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
#firewall-cmd --add-port=3389/tcp --permanent
#firewall-cmd --reload

yum -y downgrade xorg-x11-server-Xorg
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
yum -y install xrdp 
systemctl start xrdp.service

# Set XRDP service to automatically start when VM starts
chkconfig xrdp on
sleep 2s
netstat -antup | grep 3389

passwd root
```

Setup an ssh tunnel. Example: `ssh -L 8034:192.168.1.20:3389 rhel@$jumpbox`

Connect from an RDP client (e.g.: Windows + R, `mstsc`) and connect to `localhost:8034`

from the GUI, open a terminal and run 

```bash
tentativenum=180410b
/data2/db2bits/server_t/db2setup -l /tmp/db2setup_${tentativenum}.log -t /tmp/db2setup_${tentativenum}.trc
```

Documentation is [here](https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/t0054851.html?pos=2)

at this point, in this example, d1 shows the following: 

```
[root@d1 rhel]# ll /dev/mapper
total 0
crw------- 1 root root 10, 236 Apr 17 12:51 control
lrwxrwxrwx 1 root root       7 Apr 17 12:51 w1db2data1 -> ../dm-1
lrwxrwxrwx 1 root root       7 Apr 17 12:51 w1db2log1 -> ../dm-0
lrwxrwxrwx 1 root root       7 Apr 17 12:51 w1db2shared -> ../dm-2
lrwxrwxrwx 1 root root       7 Apr 17 12:51 w1db2tieb -> ../dm-3
```


Here is how the setup is filled: 

Screen name | Field | Value | Comments
------------|-------|-------|---------
Welcome | | New Install |
Choose a Product | | DB2 Version 11.1.2.2. Server Editions with DB2 pureScale |
Configuration | Directory | /data1/opt/ibm/db2/V11.1 |
'' | Select the installation type | Typical |
''| I agree to the IBM terms | checked |
Instance Owner | Existing User For Instance, User name | db2sdin1 |
Fenced User | Existing User, User name | db2sdfe1 | 
Cluster File System | Shared disk partition device path | /dev/dm-2 |
'' | Mount point | /db2sd_1804a |
'' | Shared disk for data | /dev/dm-1 |
'' | Mount point (Data) | /db2fs/datafs1 |
'' | Shared disk for log | /dev/dm-0 |
'' | Mount point (Log) | /db2fs/logfs1 |
'' | DB2 Cluster Services Tiebreaker. Device path | /dev/dm-3 |
Host List | d1 [eth1], d2 [eth1], cf1 [eth1], cf2 [eth1]|
'' | Preferred primary CF | cf1 |
'' | Preferred secondary CF | cf2 |
Response File and Summary | first option | Install DB2 Server Edition with the IBM DB2 pureScale feature and save my settings in a response file
'' | Response file name | /root/db2server.rsp

The full summary reads: 

```
                                        
Product to install:                     	DB2 Server Edition 
Installation type:                      	Custom 
                                        
Previously Installed Components:        
                                        
Components to be installed:             
    Base client support                 	
    Java support                        	
    SQL procedures                      	
    Base server support                 	
    DB2 data source support             	
    ODBC data source support            	
    Teradata data source support        	
    Spatial Extender server support     	
    Scientific Data Sources             	
    JDBC data source support            	
    IBM Software Development Kit (SDK) for Java(TM) 	
    DB2 LDAP support                    	
    DB2 Instance Setup wizard           	
    Structured file data sources        	
    Integrated Flash Copy Support       	
    General Parallel File System (GPFS) 	
    Oracle data source support          	
    Connect support                     	
    Application data sources            	
    Spatial Extender client             	
    SQL Server data source support      	
    Communication support - TCP/IP      	
    Tivoli SA MP                        	
    Base application development tools  	
    DB2 Update Service                  	
    Replication tools                   	
    Sample database source              	
    DB2 Text Search                     	
    Sybase data source support          	
    Informix data source support        	
    Federated Data Access Support       	
    IBM DB2 pureScale Feature           	
    First Steps                         	
    Guardium Installation Manager Client 	
                                        
Languages:                              
    English                             	
        All Products                    	
                                        
Target directory:                       	/opt/ibm/db2/V11.1
                                        
Maximum space required on each host:    	3300 MB
Install IBM Tivoli System Automation for Multiplatforms (Tivoli SA MP): 	Yes 
                                        
DB2 cluster services:                   
    Mount point:                        	/db2sd_1804a
    DB2 cluster services tiebreaker disk device path: 	/dev/dm-3
    DB2 cluster file system device path: 	/dev/dm-2
                                        
New instances:                          
    Instance name:                      	db2sdin1
        FCM port range:                 	60000-60005
        CF port:                        	56001
        CF Management port:             	56000
        TCP/IP configuration:           	
            Service name:               	db2c_db2sdin1
            Port number:                	50137
        Instance user information:      	
            User name:                  	db2sdin1
            UID:                        	1001
            Group name:                 	db2iadm1
            GID:                        	341
            Home directory:             	/home/db2sdin1
        Fenced user information:        	
            User name:                  	db2sdfe1
            UID:                        	1002
            Group name:                 	db2fadm1
            GID:                        	342
            Home directory:             	/home/db2sdfe1
                                        
Cluster caching facilities:             
    Preferred primary cluster caching facility: 	cf1
    Preferred secondary cluster caching facility: 	cf2
DB2 members:                            
    d1                                  	
    d2                                  	
                                        
                                        
New Host List:                          
    Host                                	Cluster Interconnect Netname 
    d1                                  	d1
    d2                                  	d2
    cf1                                 	cf1
    cf2                                 	cf2
```

this generated a reponse file (available in this repo: `db2server.rsp`) that can be used for a setup with the response file.

