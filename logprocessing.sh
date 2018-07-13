#! /bin/bash

cp $1 $1.backup

sed -i 's/Jobs.*$//g' $1

echo "Get raw fio results: "
./processing_fio.awk $1 
echo "-----"
echo ""

echo "Get rados bench results: "
./processing_rados.awk $1	
echo "-----"
echo ""

echo "Get rbd fio results: "
./processing_rbd_fio.awk $1
echo "-----"
echo ""

echo "Get rbd bench results: "
./processing_rbd_bench.awk $1
echo "-----"
echo ""
