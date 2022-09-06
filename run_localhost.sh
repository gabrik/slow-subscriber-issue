#!/usr/bin/env bash


# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
    cleanup
    exit
}

# kills all the processes
function cleanup() {
 killall zenohd > /dev/null 2>&1
 killall pubs > /dev/null 2>&1
 killall sub > /dev/null 2>&1
}


ZENOH_LOG_1ST="/tmp/1st-zenoh.log"
ZENOH_LOG_2ND="/tmp/2nd-zenoh.log"
WD=$(pwd)


PUB_1_LOG="/tmp/pub.1.log"
PUB_2_LOG="/tmp/pub.2.log"
PUB_3_LOG="/tmp/pub.3.log"
PUB_4_LOG="/tmp/pub.4.log"
PUB_5_LOG="/tmp/pub.5.log"

SUB_ALL_LOG="/tmp/sub.all.log"
SUB_SINGLE_LOG="/tmp/sub.single.log"

plog () {
   LOG_TS=`eval date "+%F-%T"`
   echo "[$LOG_TS]: $1"
}


if [ -z $ZENOH_HOME ] ; then
    ZENOH_HOME=$(pwd)
    echo "WARNING: \$ZENOH_HOME is not set";
    exit -1
else
    plog "[ INFO ] ZENOH_HOME=$ZENOH_HOME"
fi


plog "[ INIT ] Starting 1st Zenoh Router"
$ZENOH_HOME/target/release/zenohd -l tcp/127.0.0.1:9988 --no-multicast-scouting >> $ZENOH_LOG_1ST 2> /dev/null &
ZENOH_ONE_PID=$!
plog "[ INIT ] Starting 2nd Zenoh Router"
$ZENOH_HOME/target/release/zenohd -l tcp/127.0.0.1:8899 -e tcp/127.0.0.1:9988 --no-multicast-scouting >> $ZENOH_LOG_2ND 2> /dev/null &
ZENOH_TWO_PID=$!
plog "[ DONE ] Zenoh routers started ($ZENOH_ONE_PID, $ZENOH_TWO_PID)... sleeping 5s"
sleep 5

plog "[ INIT ] Starting 5 publisher for a total of ~96mbit/s"
# 24 bytes
$WD/target/release/pubs -m client --no-multicast-scouting -e tcp/127.0.0.1:9988 -k "test/one" -r 30 24 >> $PUB_1_LOG 2> /dev/null &
PUB_1_PID=$!

#16MB
$WD/target/release/pubs -m client --no-multicast-scouting -e tcp/127.0.0.1:9988 -k "test/two" -r 30 16777216 >> $PUB_2_LOG 2> /dev/null &
PUB_2_PID=$!

#16MB
$WD/target/release/pubs -m client --no-multicast-scouting -e tcp/127.0.0.1:9988 -k "test/three" -r 30 16777216 >> $PUB_3_LOG 2> /dev/null &
PUB_3_PID=$!

#16MB
$WD/target/release/pubs -m client --no-multicast-scouting -e tcp/127.0.0.1:9988 -k "test/four" -r 30 16777216 >> $PUB_4_LOG 2> /dev/null &
PUB_4_PID=$!

#32MB
$WD/target/release/pubs -m client --no-multicast-scouting -e tcp/127.0.0.1:9988 -k "test/five" -r 30 33554432 >> $PUB_5_LOG 2> /dev/null &
PUB_5_PID=$!

plog "[ DONE ] 5 Publisher running: $PUB_1_PID, $PUB_2_PID, $PUB_3_PID, $PUB_4_PID, $PUB_5_PID. Sleeping 10s"
sleep 10

plog "[ INIT ] Starting 1st Subscriber (all resources)"
$WD/target/release/sub -m client  --no-multicast-scouting -e tcp/127.0.0.1:8899 -k "test/*" >> $SUB_ALL_LOG 2> /dev/null &
SUB_ALL_PID=$!
plog "[ DONE ] Subscriber all resources: $SUB_ALL_PID"

plog "[ INIT ] Starting 2nd Subscriber (only on test/two)"
$WD/target/release/sub -m client  --no-multicast-scouting -e tcp/127.0.0.1:8899 -k "test/two" >> $SUB_SINGLE_LOG 2> /dev/null &
SUB_SINGLE_PID=$!
plog "[ DONE ] Subscriber test/two resources: $SUB_SINGLE_PID"
plog "[ INFO ] Output can be seen with 'tail -f $SUB_SINGLE_LOG' and 'tail -f $SUB_ALL_LOG'"
plog "[ INFO ] Press Ctrl-C to kill"
wait $SUB_SINGLE_PID

kill -9 $PUB_1_PID > /dev/null 2>&1
kill -9 $PUB_2_PID > /dev/null 2>&1
kill -9 $PUB_3_PID > /dev/null 2>&1
kill -9 $PUB_4_PID > /dev/null 2>&1
kill -9 $PUB_5_PID > /dev/null 2>&1
kill -9 $ZENOH_ONE_PID > /dev/null 2>&1
kill -9 $ZENOH_TWO_PID > /dev/null 2>&1

plog "[ DONE ] Hope you enjoyed the issue :P"