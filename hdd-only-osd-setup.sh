#! /bin/bash

# 1/ Create 2 physical volumes (HDD + SSD) 
pvcreate /dev/sdn
pvcreate /dev/sdd

# 2/ Create a volume group with both
vgcreate dmc-data /dev/sdn /dev/sdd

# 3/ Create logical volumes 
lvcreate -L60G -n cache dmc-data /dev/sdd
lvcreate -L1G -n meta  dmc-data /dev/sdd
lvcreate -l 100%FREE -n data  dmc-data /dev/sdn

# 4/ Create and attach a cache pool with the 2 volumes
lvconvert --type cache-pool --cachemode writeback --chunksize 4K --poolmetadata dmc-data/meta dmc-data/cache
lvconvert --type cache --cachepool dmc-data/cache dmc-data/data


# 5/ Create OSD
ceph-volume lvm create --bluestore  --data dmc-data/data
ceph osd pool create pool_dmc 32 replicated jcollet_hdd 4
ceph osd pool set pool_dmc min_size 1
ceph osd pool set pool_dmc size 1
ceph osd add-bucket dmc root
ceph osd crush add-bucket dmc root
ceph osd crush move osd.4 root=dmc
ceph osd crush rule create-replicated dmc dmc osd
ceph osd pool set pool_dmc crush_rule dmc

# 5/ Create rbd testbed
rbd create pool_dmc/test -s 1G 

