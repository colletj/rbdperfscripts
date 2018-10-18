#!/usr/bin/awk -f

# processing_fio.awk
# extract fio statistics (raw disks usage)


BEGIN {
  out=0;
  print "DriveType IoDepth IOPS AverageLatency(ms) RunTime UtilTime" 
  curDisk = "ssd"
}

{
  if($0 ~ "RBD level") { out=1; }
  if($0 ~ "RBD bench level") { out=0; }


  if(out)
  {
    if($0 ~ /IOPS[=:]/)
    {
      gsub(/IOPS=/,"");
      gsub(/,/,"");
      if($2 ~ /[0-9\.]+k/)
      {
        gsub(/k/,"");
        $2 = $2*1000;
      }

      printf $2" ";
    } 

    if($0 ~ / lat \([um]?sec\)[=:]/)
    {
      gsub(/avg=/,"");
      gsub(/,/,"");
      if($0 ~ /\(usec\)/) { $5 = $5/1000; }
      if($0 ~ /\(sec\)/) { $5 = $5*1000; }
     
      printf $5" ";
    }

    if($0 ~ /performed in:/)
    {
      $3 = $3*1000;
      printf $3" \n";
    } 

    if($0 ~ /pid=/)
    {
      if($0 ~ /rbd_iodepth[0-9]+/) 
      {
        gsub(/[a-zA-Z_:]/,"")
        printf curDisk" "$1" "
      }
    }
  }

}

END {
}
