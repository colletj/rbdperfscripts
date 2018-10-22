#!/usr/bin/awk -f

# processing_fio.awk
# extract fio statistics (raw disks usage)


BEGIN {
  out=1;
  print "DriveType IoDepth IOPS AverageLatency(ms) RunTime UtilTime" 
}

{
  if(out)
  {
    if($0 ~ "RADOS") { out=0; }

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
      printf $3" ";
    } 

    if($0 ~ /util time:/)
    {
      print $3;
    }

    if($0 ~ /vdb_/) 
    {
      if($0 ~ /pid/) 
      {
	gsub(/_/," "); 
        printf $1" "$3" "; 
      } 
    }
  }

}

END {
}
