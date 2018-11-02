# rbdperfscripts

Simple ceph-rbd single-node I/O performance benchmarking scripts.
The master branch holds the most generic version of the bench suite while specialized branchs where added when needed.


## Architecture
The benchmark is decomposed into 4 parts to evaluate performances at different levels, namely:
- Raw disk level: fio
- Rados level: rados bench
- Librbd level: fio (rbd)
- Librbd level: rbd bench

## Disk configuration expected
The configurations expected by the script are the following: 
- HDD-only 
- SSD-only
- Mixed configurations:
  - Bluestore (SSD: db, HDD: data): see [wip]
  - Filestore (SSD: journal, HDD: data): see [wip]
  - dmcache setup: see dmcache-osd-setup.sh 
