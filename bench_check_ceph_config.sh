#! /bin/bash
# 
# Usage:
# bench_check_ceph_config.sh

 usage="./bench_check_ceph_config.sh OPTIONS

with OPTIONS
    -h show this help text
    -m include testing mixed configuration
    -f include testing mixed filestore configuration
    -s include testing ssd-only configuration
    -d include testing hdd-only configuration
    -c include testing dm-cache configuration
"

while getopts 'hmfsdca' opt; do
  case "$opt" in
   h) echo "$usage"
      exit
      ;;
   m) testing_mix=1;
      ;;
   f) testing_mfs=1;
      ;;
   s) testing_ssd=1;
      ;;
   d) testing_hdd=1;
      ;;
   c) testing_dmc=1;
      ;;
   a) testing_mix=1
      testing_mfs=1
      testing_ssd=1
      testing_hdd=1
      testing_dmc=1
      ;;
  esac
done
shift $((OPTIND - 1))


echo "Preflight checklist:"

if [ ! -z $testing_mix ]; then echo "test mixed configuration          "; fi
if [ ! -z $testing_mfs ]; then echo "test mixed filestore configuration"; fi
if [ ! -z $testing_ssd ]; then echo "test ssd-only configuration       "; fi
if [ ! -z $testing_hdd ]; then echo "test hdd-only configuration       "; fi
if [ ! -z $testing_dmc ]; then echo "test dm-cache configuration       "; fi
echo ""
echo ""

if [ ! -z $testing_mix ];
then
  echo "[MIX] Starting checks";
  ceph osd lspools | grep "pool_mix" -q;
  if [ $? -eq 0 ];
  then
    echo "[MIX]   Pool exists";
    if [ $? -eq 0 ]; 
    rbd info pool_mix/test > /dev/null;
    then 
      echo "[MIX]   RBD image exists"; 
    else 
      echo "[MIX]   RBD image not found";
      exit 1
    fi
  else
    echo "[MIX]   Pool does not exists"
    exit 1
    #TODO ask if create the missing pool
  fi
fi
echo ""

if [ ! -z $testing_mfs ];
then
  echo "[MFS] Starting checks";
  ceph osd lspools | grep "pool_fs" -q;
  if [ $? -eq 0 ];
  then
    echo "[MFS]   Pool exists";
    rbd info pool_fs/test > /dev/null;
    if [ $? -eq 0 ]; 
    then 
      echo "[MFS]   RBD image exists"; 
    else 
      echo "[MFS]   RBD image not found";
      exit 1
    fi
  else
    echo "[MFS]   Pool does not exists"
    exit 1
    #TODO ask if create the missing pool
  fi
fi
echo ""

if [ ! -z $testing_hdd ];
then
  echo "[HDD] Starting checks";
  ceph osd lspools | grep "pool_hdd" -q;
  if [ $? -eq 0 ];
  then
    echo "[HDD]   Pool exists";
    rbd info pool_hdd/test > /dev/null;
    if [ $? -eq 0 ]; 
    then 
      echo "[HDD]   RBD image exists"; 
    else 
      echo "[HDD]   RBD image not found";
      exit 1
    fi
  else
    echo "[HDD]   Pool does not exists"
    exit 1
    #TODO ask if create the missing pool
  fi
fi
echo ""

if [ ! -z $testing_ssd ];
then
  echo "[SSD] Starting checks";
  ceph osd lspools | grep "pool_ssd" -q;
  if [ $? -eq 0 ];
  then
    echo "[SSD]   Pool exists";
    rbd info pool_ssd/test > /dev/null;
    if [ $? -eq 0 ]; 
    then 
      echo "[SSD]   RBD image exists"; 
    else 
      echo "[SSD]   RBD image not found";
      exit 1
    fi
  else
    echo "[SSD]   Pool does not exists"
    exit 1
    #TODO ask if create the missing pool
  fi
fi
echo ""

if [ ! -z $testing_dmc ];
then
  echo "[DMC] Starting checks";
  ceph osd lspools | grep "pool_dmc" -q;
  if [ $? -eq 0 ];
  then
    echo "[DMC]   Pool exists";
    rbd info pool_dmc/test > /dev/null;
    if [ $? -eq 0 ]; 
    then 
      echo "[DMC]   RBD image exists"; 
    else 
      echo "[DMC]   RBD image not found";
      exit 1
    fi
  else
    echo "[DMC]   Pool does not exists"
    exit 1
   #TODO ask if create the missing pool
  fi
  
fi
echo ""

