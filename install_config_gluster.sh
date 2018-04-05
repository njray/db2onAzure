#!/bin/bash

#install and configure gluster

#setup DNS static
cat >> /etc/hosts <<EOF
192.168.1.10 g1
192.168.1.11 g2
192.168.1.12 g3

192.168.2.10 g1b
192.168.2.11 g2b
192.168.2.12 g3b
EOF

#Install stuff
yum update -y
cat >> /etc/yum.repos.d/Gluster.repo <<EOF
[gluster38]
name=Gluster 3.8
baseurl=http://mirror.centos.org/centos/7/storage/$basearch/gluster-3.8/
gpgcheck=0
enabled=1
EOF

yum install glusterfs glusterfs-cli glusterfs-libs  -y
yum install -y  glusterfs-cli glusterfs-libs glusterfs-server

#prepare the disks
pvcreate /dev/sdc
pvcreate /dev/sdd
vgcreate vg_gluster /dev/sdc /dev/sdd

lvcreate -L 90G -n brick1 vg_gluster
lvcreate -L 9G -n brick2 vg_gluster

mkfs.xfs /dev/vg_gluster/brick1
mkfs.xfs /dev/vg_gluster/brick2

mkdir -p /bricks/db2data
mkdir -p /bricks/db2quorum

mount /dev/vg_gluster/brick1 /bricks/db2data/
mount /dev/vg_gluster/brick2 /bricks/db2quorum/

mkdir -p /bricks/db2data/db2data
mkdir -p /bricks/db2quorum/db2quorum

cat >> /etc/fstab <<EOF
/dev/vg_gluster/brick1  /bricks/db2data    xfs     defaults    0 0
/dev/vg_gluster/brick2  /bricks/db2quorum    xfs     defaults    0 0
EOF

#firewall
firewall-cmd --zone=public --add-port=24007-24008/tcp --permanent
firewall-cmd --zone=public --add-port=49152-49160/tcp --permanent
firewall-cmd --reload

#start gluster
systemctl enable glusterd
systemctl start glusterd

gluster peer probe g1b
gluster peer probe g2b
gluster peer probe g3b

gluster pool list

mkdir -p /db2/data
mkdir -p /db2/quorum

#create gluster volumes
gluster volume create db2data replica 3 g1b:/bricks/db2data/db2data g2b:/bricks/db2data/db2data g3b:/bricks/db2data/db2data
gluster volume create db2quorum replica 3 g1b:/bricks/db2quorum/db2quorum g2b:/bricks/db2quorum/db2quorum g3b:/bricks/db2quorum/db2quorum

gluster volume start db2data
gluster volume start db2quorum

#gluster block

yum -y install http://cbs.centos.org/kojifiles/packages/tcmu-runner/1.3.0/0.2rc4.el7/x86_64/libtcmu-1.3.0-0.2rc4.el7.x86_64.rpm
yum -y install http://cbs.centos.org/kojifiles/packages/tcmu-runner/1.3.0/0.2rc4.el7/x86_64/tcmu-runner-1.3.0-0.2rc4.el7.x86_64.rpm
yum -y install http://cbs.centos.org/kojifiles/packages/tcmu-runner/1.3.0/0.2rc4.el7/x86_64/tcmu-runner-handler-glfs-1.3.0-0.2rc4.el7.x86_64.rpm
yum -y install http://cbs.centos.org/kojifiles/packages/gluster-block/0.3/2.el7/x86_64/gluster-block-0.3-2.el7.x86_64.rpm

systemctl start gluster-blockd
systemctl enable gluster-blockd
systemctl status gluster-blockd

#create gluster-block device file
gluster-block create sampleVol/elasticBlock ha 3 10.70.35.109,10.70.35.104,10.70.35.51 40GiB