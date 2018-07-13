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
"

while getopts 'hr:m:f:s:d:' opt; do
  case "$opt" in
    h) echo "$usage"
       exit
       ;;
    r) disk_target_ssd=`echo $OPTARG | sed 's/,.*//'`
       disk_target_hdd=`echo $OPTARG | sed 's/.*,//'`
       ;;
    m) osd_mix_ssd=`echo $OPTARG | sed 's/,.*//'`
       osd_mix_hdd=`echo $OPTARG | sed 's/.*,//'`
       ;;
    f) osd_fs_ssd=`echo $OPTARG | sed 's/,.*//'`
       osd_fs_hdd=`echo $OPTARG | sed 's/.*,//'`
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

# disk_target_ssd : sdd
# disk_target_hdd : sdh
# osd_ssd : sdc 
# osd_hdd : sdg
# osd_mix_ssd : sde
# osd_mix_hdd : sdj
# osd_fs_ssd : sdf
# osd_fs_hdd : sdl

# Disk level
blocksize=4K

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

sleep 10

# Rados level
echo "RADOS level"

for i in 1 2 4 8 12 16 32;
do
  start=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_ssd 45 write --no-cleanup  -t $i -b 4096
  end=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: " $(( $end - $start ))

  start=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_hdd 45 write --no-cleanup  -t $i -b 4096
  end=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: " $(( $end - $start ))

  start_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  start_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_mix 45 write --no-cleanup  -t $i -b 4096
  end_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  end_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: (hdd) " $(( $end_1 - $start_1 ))
  echo "util time: (ssd) " $(( $end_2 - $start_2 ))

  start_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  start_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "performed in: %e secs\nCPU: %P" rados bench -p pool_fs 45 write --no-cleanup  -t $i -b 4096
  end_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  end_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: (hdd) " $(( $end_1 - $start_1 ))
  echo "util time: (ssd) " $(( $end_2 - $start_2 ))

  sleep 5

  rados -p pool_ssd cleanup
  rados -p pool_hdd cleanup
  rados -p pool_mix cleanup
  rados -p pool_fs cleanup
done

sleep 10

# RBD level
echo "RBD level"

for i in `ls rbd_ssd_*.fio`;
do
  start=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
  end=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: " $(( $end - $start ))
done


echo "Switching..."
for i in `ls rbd_hdd_*.fio`;
do
  start=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "performed in: %e secs\nCPU: %P" fio $i;
  end=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: " $(( $end - $start ))
done

echo "Switching again..."
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

echo "Switching again..."
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

#RBD bench level
echo "RBD bench level"
for i in 1 2 4 8 16 32; 
do
  start=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "CPU: %P" rbd bench  pool_ssd/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
  end=`egrep "\b$osd_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: " $(( $end - $start ))

  echo "Switching.."
  start=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "CPU: %P" rbd bench  pool_hdd/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
  end=`egrep "\b$osd_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: " $(( $end - $start ))

  echo "Switching.."
  start_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  start_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "CPU: %P" rbd bench  pool_mix/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
  end_1=`egrep "\b$osd_mix_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  end_2=`egrep "\b$osd_mix_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: (hdd) " $(( $end_1 - $start_1 ))
  echo "util time: (ssd) " $(( $end_2 - $start_2 ))

  echo "Switching.."
  start_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`;
  start_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`;
  /usr/bin/time -f "CPU: %P" rbd bench  pool_fs/test --io-type write --io-pattern rand  --io-total 512M --io-threads $i
  end_1=`egrep "\b$osd_fs_hdd\b" /proc/diskstats | awk '{ print $13 }'`
  end_2=`egrep "\b$osd_fs_ssd\b" /proc/diskstats | awk '{ print $13 }'`
  echo "util time: (hdd) " $(( $end_1 - $start_1 ))
  echo "util time: (ssd) " $(( $end_2 - $start_2 ))
  
  echo "Switching.."
done