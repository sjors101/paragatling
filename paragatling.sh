#!/bin/bash
# paragatling - To run Gatling parallel with multiple hosts
# Author: Sjors101 <https://github.com/sjors101/>, 09/08/2017
#
# Notes:
# - Change User and the Gatling details to your need.
# - The host variable must contain your "other" gatling IP/DNS address. It is possible to define multiple hosts, which must be seperated with a space.
# - Make sure the ssh-rsa (/home/user/paragatling.pem) is copyed to the other hosts /home/ssh/user

#===== User/host details =====#
USER_NAME='user'
HOSTS=( 1.1.1.1 1.1.1.2 1.1.1.3 )
PEM_FILE=/home/user/paragatling.pem

#===== Gatling details =====#
GATLING_SIMULATIONS_DIR=/opt/gatling/user-files/simulations/
GATLING_RUNNER=/opt/gatling/bin/gatling.sh
GATLING_REPORT_DIR=/opt/gatling/results/

#********** No need to change stuff below **********#
#Reading available stimulations 
scalaFiles=$(ls -t $GATLING_SIMULATIONS_DIR | grep scala | awk -F "." '{print $1}')
count=1

echo "Pick an simulation number, followed by [ENTER]:"
for i in $scalaFiles
do
  echo [$count]: $i
  ((count++))
  scalaArray+=("$i")
done
read simNumber

SIMULATION_NAME=${scalaArray[simNumber-1]}
echo "Starting paragatling for simulation: $SIMULATION_NAME"

# Creating temp directory
GATLING_TEMP_DIR=/tmp/gatling/$(date +%Y%m%d-%H%M%S)-$SIMULATION_NAME/
mkdir -p $GATLING_TEMP_DIR

# clean-up > 10 simulations 
if [[ $(ls -t $GATLING_REPORT_DIR | wc -l) -gt 10 ]]
then
   echo "Deleting $(ls -t | tail -n +11)"
   ls -t | tail -n +11 | xargs -d '\n' rm -rf
fi

# cleaning remote dir
for HOST in "${HOSTS[@]}"
do
  ssh -i $PEM_FILE -n -f $USER_NAME@$HOST "sh -c 'rm -rf $GATLING_REPORT_DIR'"
done

# coppying simulation
for HOST in "${HOSTS[@]}"
do
  scp -i $PEM_FILE -r $GATLING_SIMULATIONS_DIR/* $USER_NAME@$HOST:$GATLING_SIMULATIONS_DIR > /dev/null 2>&1
done

# running on remote hosts
for HOST in "${HOSTS[@]}"
do
  echo ""
  echo "Running simulation on host: $HOST"
  ssh -i $PEM_FILE -n -f $USER_NAME@$HOST "sh -c 'nohup $GATLING_RUNNER -nr -s $SIMULATION_NAME > /opt/gatling/log/run.log 2>&1 &'"
done

# running on localhost
echo "Running simulation on localhost"
$GATLING_RUNNER -nr -s $SIMULATION_NAME
  
# move localhost simulation and delete old folder
mv "${GATLING_REPORT_DIR}$(ls -t $GATLING_REPORT_DIR | head -n 1)"/* $GATLING_TEMP_DIR/
rm -rf "${GATLING_REPORT_DIR}$(ls -t $GATLING_REPORT_DIR | head -n 1)"

# move simulation for remote hosts, unfortunately the sleeps are needed else the scp gets f*cked
for HOST in "${HOSTS[@]}"
do
  echo "Gathering result file from host: $HOST"
  sleep 3
  scp -i $PEM_FILE $USER_NAME@$HOST:${GATLING_REPORT_DIR}*/simulation.log ${GATLING_TEMP_DIR}simulation-$HOST.log
  sleep 2
done

mv $GATLING_TEMP_DIR $GATLING_REPORT_DIR
$GATLING_RUNNER -ro "${GATLING_REPORT_DIR}$(ls -t $GATLING_REPORT_DIR | head -n 1)"