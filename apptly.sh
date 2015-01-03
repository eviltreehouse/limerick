#!/bin/bash
APPTLY_DIR=/opt/apptly
APPLIST=apps.list
APPSDIR=/opt/apps

start() {
	for app in $(cat $APPTLY_DIR/$APPLIST); do
	 #echo $app
	 echo "[.] Starting $app";
	 cd $APPSDIR/$app/bin
	 ./run.pl &
	 echo $! > tmp/run.pid
	 cd $APPTLY_DIR
	done
}

stop() {
	for app in $(cat $APPTLY_DIR/$APPLIST); do
	 kpid=$(cat $APPSDIR/$app/bin/tmp/run.pid 2>/dev/null)
	 if [ "$?" -ne "0" ]
	 then
	  continue
	 fi
	 if [ "$kpid" -ne "0" ]
	 then
	  echo "[.] Killing $app / PID $kpid"
	  kill $kpid	  
	  rm -f $APPSDIR/$app/bin/tmp/run.pid
	 fi
	done	
}

case "$1" in
	start)
              	start
		exit 0
        ;;
	stop)
             	stop
		exit 0
        ;;
	*)
          	echo "Usage: apptly start|stop"
                exit 1
        ;;
esac

