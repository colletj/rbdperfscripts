#!/usr/bin/awk -f

# processing_fio.awk
# extract fio statistics (raw disks usage)


BEGIN {
  out=0;
  curDisk="dmc";
  print "DriveType IoDepth IOPS RunTime" 
}

{
  if(out)
  {
    if($0 ~ /bench/)
    {
      printf curDisk" "$7" ";
    }

    if($0 ~ /elapsed:/)
    {
      printf $6" "$2*1000" \n";
    } 
  }

  if($0 ~ "RBD bench level") { out=1; }
}

END {
}
