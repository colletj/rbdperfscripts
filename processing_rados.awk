#!/usr/bin/awk -f

# processing_fio.awk
# extract fio statistics (raw disks usage)


BEGIN {
  out=0;
  curDrive ="ssd";
  print "DriveType IOPS AverageLatency(ms) RunTime" 
}

{
  if($0 ~ "RADOS level") { out=1; }
  if($0 ~ "RBD level") { out=0; }

  if(out)
  {
    
    if($0 ~ /Average IOPS:/)
    {
      gsub(/IOPS:/,"");
      gsub(/,/,"");
      printf curDrive" "($2+0)" ";
    } 

    if($0 ~ /Average Latency/)
    {
      printf $3*1000" ";
    }

    if($0 ~ /performed in:/)
    {
      $3 = $3*1000;
      printf $3" \n";
    } 
  }

}

END {
}
