#!/system/bin/sh
# crontab rule: 0 4 * * * /sdcard/nosync/profile/pbin/android/n4/n4upkeep.sh
(
  # init
  date
  PATH="/sdcard/nosync/profile/pbin/android:$PATH"

  # mount directories
  mkdir -p /sdcard/abin /sdcard/pbin
  su root -- >/dev/null <<EOF
mount -o bind,rw /sdcard/nosync/profile/pbin /sdcard/pbin
mount -o bind,rw /sdcard/nosync/profile/pbin/android /sdcard/abin
EOF

  # update repos
  (cd /sdcard/nosync/profile; git fetch; git merge)

  # remove old backups
  ( cd /sdcard
    git annex numcopies 1
    find /sdcard/backup/mybackup -type d -name 'AppsMedia_*' | 
      sort -r | tail -n -1 | 
      xargs echo git annex drop
  )

  # annex files
  . annex_up.sh -b /sdcard -w wlan0 -c rpi -f -g

  # end
  date
) >/sdcard/n4upkeep.log 2>&1