#! /bin/bash

lvremove $1 
vgremove $1 
pvremove $2
ceph-volume lvm zap $2
