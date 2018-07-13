#!/usr/bin/awk -f

# processing_fio.awk
# extract fio statistics (raw disks usage)


BEGIN {
  out=0;
  curDisk="mix";
  print "DriveType IoDepth IOPS RunTime UtilTime" 
}

{
  if(out)
  {
    if($0 ~ /random/) 
    { 
      if(curDisk ~ /hdd/) { curDisk="mix"; }
      else if(curDisk ~ /ssd/) { curDisk="hdd"; }
      else if(curDisk ~ /mix/) { curDisk="ssd"; }
    }

    if($0 ~ /bench/)
    {
      printf curDisk" "$7" ";
    }

    if($0 ~ /elapsed:/)
    {
      printf $6" "$2*1000" ";
    } 

    if($0 ~ /util time:/)
    {

      if(curDisk ~ /mix/) 
      {
        if($0 ~ /\(hdd\)/)       { printf ($4+0)" "; }
        else if($0 ~ /\(ssd\)/)  { printf ($4+0)" \n";  }
      }
      else                       { printf ($3+0)" \n";  }
    }
  }

  if($0 ~ "RBD bench level") { out=1; }
}

END {
}
