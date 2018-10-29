#! /bin/bash
# 
# Usage: 
# bench_suite.sh -r sdd,sdh -m sde,sdj -f sdf,sdl -s sdc -d sdg

usage="./bench_suite.sh OPTIONS

with OPTIONS
    -h show this help text
    -r <ssd1,hdd1> set raw disks to be tested with fio, ssd first then hdd (e.g. -r sdd,sdh)
    -m <ssd2,hdd2> set disks used in the mixed configuration, ssd first then hdd (e.g. -m sde,sdj)
    -f <ssd3,hdd3> set disks used in the mixed filestore configuration, ssd first then hdd (e.g. -f sdf,sdl)
    -s <ssd> set disk used in ssd-only configuration (e.g. -s sdc)
    -d <ssd> set disk used in hdd-only configuration (e.g. -d sdg)
    -c <ssd4,hdd4> set disks used in the dm-cache configuration, ssd first then hdd (e.g. -m sdd,sdn)
"

while getopts 'hc:r:m:f:s:d:' opt; do
  case "$opt" in
    h) echo "$usage"
       exit
       ;;
    r) disk_target_ssd=`echo $OPTARG | sed 's/,.*//'`
       disk_target_hdd=`echo $OPTARG | sed 's/.*,//'`
       ;;
    m) osd_mix_ssd=`echo $OPTARG | sed 's/,.*//'`
       osd_mix_hdd=`echo $OPTARG | sed 's/.*,//'`
       osd_mix=1;
       ;;
    c) osd_dmc_ssd=`echo $OPTARG | sed 's/,.*//'`
       osd_dmc_hdd=`echo $OPTARG | sed 's/.*,//'`
       osd_dmc=1;
       ;;
    f) osd_fs_ssd=`echo $OPTARG | sed 's/,.*//'`
       osd_fs_hdd=`echo $OPTARG | sed 's/.*,//'`
       osd_fs=1;
       ;;
    s) osd_ssd=$OPTARG
       ;;
    d) osd_hdd=$OPTARG
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

echo 3 | tee /proc/sys/vm/drop_caches && sync

echo "Checking arguments:"
if [ ! -z $disk_target_ssd ]; then echo "disk_target_hdd: $disk_target_hdd"; fi
if [ ! -z $disk_target_hdd ]; then echo "disk_target_ssd: $disk_target_ssd"; fi

if [ ! -z $osd_mix_ssd ]; then echo "osd_mix_hdd: $osd_mix_hdd"; fi
if [ ! -z $osd_mix_hdd ]; then echo "osd_mix_ssd: $osd_mix_ssd"; fi

if [ ! -z $osd_fs_ssd ]; then echo "osd_fs_hdd: $osd_fs_hdd"; fi
if [ ! -z $osd_fs_hdd ]; then echo "osd_fs_ssd: $osd_fs_ssd"; fi

if [ ! -z $osd_dmc_ssd ]; then echo "osd_dmc_hdd: $osd_dmc_hdd"; fi
if [ ! -z $osd_dmc_hdd ]; then echo "osd_dmc_ssd: $osd_dmc_ssd"; fi


if [ ! -z $osd_ssd ]; then echo "osd_ssd: $osd_ssd"; fi
if [ ! -z $osd_hdd ]; then echo "osd_hdd: $osd_hdd"; fi

# disk_target_ssd : sdd
# disk_target_hdd : sdh
# osd_ssd : sdc 
# osd_hdd : sdg
# osd_mix_ssd : sde
# osd_mix_hdd : sdj
# osd_fs_ssd : sdf
# osd_fs_hdd : sdl
# osd_dmc_ssd : sdd
# osd_dmc_hdd : sdn

# Preflight checks

if [ ! -z $osd_ssd ]; then
 ./bench_check_ceph_config.sh -s
 if [ $? -eq 1 ]; then unset $osd_ssd; fi
fi

if [ ! -z $osd_hdd ]; then
 ./bench_check_ceph_config.sh -d
 if [ $? -eq 1 ]; then unset $osd_hdd; fi
fi

if [ ! -z $osd_mix ]; then
 ./bench_check_ceph_config.sh -m
 if [ $? -eq 1 ]; then unset $osd_mix; fi
fi

if [ ! -z $osd_fs  ]; then
 ./bench_check_ceph_config.sh -f
 if [ $? -eq 1 ]; then unset $osd_fs; fi
fi

if [ ! -z $osd_dmc ]; then
 ./bench_check_ceph_config.sh -c
 if [ $? -eq 1 ]; then unset $osd_dmc; fi
fi

# Disk level
blocksize=4K

if [[ -z $osd_ssd || -z $osd_hdd ]]; then echo "[FIO] Skipping raw disk test. At least a disk was not provided by the user (2 expected)." ;
else
  for iod in 1 2 4 8 16 32;
  do 
    for target in $disk_target_ssd $disk_target_hdd; 
    do
      start=`egrep "\b$target\b" /proc/diskstats | awk '{ print $13 }'`;
      /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio --filename=/dev/$target --direct=1 --sync=1 --rw=randwrite --bs=$blocksize --numjobs=1 --iodepth=$iod --runtime=60 --time_based --ioengine=libaio --group_reporting --name="$target"_"$blocksize"_"$iod"_test_run_00 
      end=`egrep "\b$target\b" /proc/diskstats | awk '{ print $13 }'`
      echo "util time: " $(( $end - $start ))
    done
  done
fi

sleep 10

# Rados level
echo "RADOS level"

for i in 1 2 4 8 12 16 32;
do
  if [ -z $osd_ssd ]; then echo "[RADOS] Skipping ssd run ($i)." ;
  else
    start=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_ssd 45 write --no-cleanup  -t $i -b 4096
    end=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: " $(( $end - $start ))
  fi
 
  if [ -z $osd_hdd ]; then echo "[RADOS] Skipping hdd run ($i)." ;
  else
    start=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_hdd 45 write --no-cleanup  -t $i -b 4096
    end=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: " $(( $end - $start ))
  fi
  
  if [ -z $osd_mix ]; then echo "[RADOS] Skipping mix run ($i)." ;
  else
    start_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_mix 45 write --no-cleanup  -t $i -b 4096
    end_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  fi

  if [ -z $osd_fs ]; then echo "[RADOS] Skipping fs run ($i)." ;
  else
    start_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_fs 45 write --no-cleanup  -t $i -b 4096
    end_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  fi
  
  if [ -z $osd_dmc ]; then echo "[RADOS] Skipping dmc run ($i)." ;
  else
    start_1=`egrep "\b$osd_dmc_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_dmc_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_dmc 45 write --no-cleanup  -t $i -b 4096
    end_1=`egrep "\b$osd_dmc_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_dmc_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  fi

  sleep 5

  if [ ! -z $osd_ssd ]; then rados -p pool_ssd cleanup; fi
  if [ ! -z $osd_ssd ]; then rados -p pool_hdd cleanup; fi
  if [ ! -z $osd_ssd ]; then rados -p pool_mix cleanup; fi
  if [ ! -z $osd_ssd ]; then rados -p pool_dmc cleanup; fi
  if [ ! -z $osd_ssd ]; then rados -p pool_fs cleanup; fi
done

sleep 10

# RBD level
echo "RBD level"

if [ -z $osd_ssd ]; then echo "[FIO/RBD] Skipping fio rbd test for ssd osd." ;
else
  for i in `ls rbd_ssd_*.fio`;
  do
    start=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
    end=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: " $(( $end - $start ))
  done
fi

echo "Switching..."
if [ -z $osd_hdd ]; then echo "[FIO/RBD] Skipping fio rbd test for hdd osd." ;
else
  for i in `ls rbd_hdd_*.fio`;
  do
    start=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
    end=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: " $(( $end - $start ))
  done
fi

echo "Switching again..."
if [ -z $osd_mix ]; then echo "[FIO/RBD] Skipping fio rbd test for mix osd." ;
else
  for i in `ls rbd_mix_*.fio`;
  do
    start_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
    end_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  done
fi

echo "Switching again..."
if [ -z $osd_fs ]; then echo "[FIO/RBD] Skipping fio rbd test for fs osd." ;
else
  for i in `ls rbd_fs_*.fio`;
  do
    start_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
    end_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  done;
fi

echo "Switching again..."
if [ -z $osd_dmc ]; then echo "[FIO/RBD] Skipping fio rbd test for dmc osd." ;
else
  for i in `ls rbd_dmc_*.fio`;
  do
    start_1=`egrep "\b$osd_dmc_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_dmc_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
    end_1=`egrep "\b$osd_dmc_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_dmc_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  done;
fi

#RBD bench level
echo "RBD bench level"
for i in 1 2 4 8 16 32; 
do
  if [ -z $osd_ssd ]; then echo "[RADOS] Skipping ssd run ($i)." ;
  else
    start=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "CPU: %P" rbd bench  pool_ssd/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
    end=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: " $(( $end - $start ))
  fi
  
  echo "Switching.."
  if [ -z $osd_hdd ]; then echo "[RADOS] Skipping hdd run ($i)." ;
  else
    start=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "CPU: %P" rbd bench  pool_hdd/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
    end=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: " $(( $end - $start ))
  fi
  
  echo "Switching.."
  if [ -z $osd_mix ]; then echo "[RADOS] Skipping mix run ($i)." ;
  else
    start_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "CPU: %P" rbd bench  pool_mix/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
    end_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  fi
  
  echo "Switching.."
  if [ -z $osd_fs ]; then echo "[RBD] Skipping fs run ($i)." ;
  else
    start_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "CPU: %P" rbd bench  pool_fs/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
    end_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  fi
    
  echo "Switching.."
  if [ -z $osd_dmc ]; then echo "[RBD] Skipping dmc run ($i)." ;
  else
    start_1=`egrep "\b$osd_dmc_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
    start_2=`egrep "\b$osd_dmc_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
    /usr/bin/time -f "CPU: %P" rbd bench  pool_dmc/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
    end_1=`egrep "\b$osd_dmc_hdd\b" /proc/diskstats | awk '{ print $13 }'`
    end_2=`egrep "\b$osd_dmc_ssd\b" /proc/diskstats | awk '{ print $13 }'`
    echo "util time: (hdd) " $(( $end_1 - $start_1 ))
    echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  fi
done
