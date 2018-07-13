#!/usr/bin/awk -f

# processing_fio.awk
# extract fio statistics (raw disks usage)


BEGIN {
  out=0;
  curDrive ="ssd";
  print "DriveType IOPS AverageLatency(ms) RunTime UtilTime" 
}

{
  if($0 ~ "RADOS") { out=1; }
  if($0 ~ "RBD") { out=0; }

  if(out)
  {
    
    if($0 ~ /Average IOPS:/)
    {
      gsub(/IOPS:/,"");
      gsub(/,/,"");
      printf curDrive" "($2+0)" ";

      if(curDrive ~ /hdd/) { curDrive = "mix" }
      else if(curDrive ~ /ssd/) { curDrive = "hdd" }
      else if(curDrive ~ /mix/) { curDrive = "ssd" }
    } 

    if($0 ~ /Average Latency/)
    {
      printf $3*1000" ";
    }

    if($0 ~ /performed in:/)
    {
      $3 = $3*1000;
      printf $3" ";
    } 

    if($0 ~ /util time:/)
    {
      if(curDrive ~ "ssd")
      {
        if($0 ~ /\(hdd\)/)       { printf ($4+0)" "; }
        else if($0 ~ /\(ssd\)/)  { printf ($4+0)" \n";  }
      }
      else { print ($3+0); }
    }
    
  }

}

END {
}
