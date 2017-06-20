#!/bin/bash

##################################################################################
function usage(){
  echo "usage: $(basename $0) /path/to/jenkins_home s3_bucket s3_path"
  echo "docker run -it --rm -e \"HOME=/home\" -e JENKINS_HOME=/path/to/jenkins/inside/container -e S3_BUCKET=<Your_S3_Bucket> -e S3_PATH=path/to/jenkins/in/S3 -v /path/to/aws/creds/.aws:/home/.aws -v /path/to/jenkins/on/host:/root/jenkins bambash/jenkins2aws"
}
##################################################################################

readonly DATE=$(date +'%h-%d-%Y_%H-%M-%S')
readonly DEST_FILE=Jenkins-$DATE.tar.gz
readonly CUR_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
readonly TMP_DIR="$CUR_DIR/tmp"
readonly ARC_NAME="jenkins-backup"
readonly ARC_DIR="$TMP_DIR/$ARC_NAME"
readonly TMP_TAR_NAME="$TMP_DIR/archive.tar.gz"

if [ -z "$JENKINS_HOME" -o -z "$DEST_FILE" ] ; then
  usage >&2
  exit 1
fi

rm -rf "$ARC_DIR" "$TMP_TAR_NAME"
for i in plugins jobs users secrets nodes;do
  mkdir -p "$ARC_DIR"/$i
done

cp "$JENKINS_HOME/"*.xml "$ARC_DIR"

cp "$JENKINS_HOME/plugins/"*.[hj]pi "$ARC_DIR/plugins"
hpi_pinned_count=$(find $JENKINS_HOME/plugins/ -name *.hpi.pinned | wc -l)
jpi_pinned_count=$(find $JENKINS_HOME/plugins/ -name *.jpi.pinned | wc -l)
if [ $hpi_pinned_count -ne 0 -o $jpi_pinned_count -ne 0 ]; then
  cp "$JENKINS_HOME/plugins/"*.[hj]pi.pinned "$ARC_DIR/plugins"
fi

if [ "$(ls -A $JENKINS_HOME/users/)" ]; then
  cp -R "$JENKINS_HOME/users/"* "$ARC_DIR/users"
fi

if [ "$(ls -A $JENKINS_HOME/secrets/)" ] ; then
  cp -R "$JENKINS_HOME/secrets/"* "$ARC_DIR/secrets"
fi

if [ "$(ls -A $JENKINS_HOME/nodes/)" ] ; then
  cp -R "$JENKINS_HOME/nodes/"* "$ARC_DIR/nodes"
fi

function backup_jobs {
  local run_in_path=$1
  if [ -d "$run_in_path" ]; then
    cd "$run_in_path"
    find . -maxdepth 1 -type d | while read job_name ; do
      [ -d "$job_name" ] && mkdir -p "$ARC_DIR/jobs/$job_name/"
      rsync -av "$job_name/" "$ARC_DIR/jobs/$job_name/"
    done
    #echo "Done in $(pwd)"
    cd -
  fi  
}

if [ "$(ls -A $JENKINS_HOME/jobs/)" ] ; then
  backup_jobs $JENKINS_HOME/jobs/
fi

cd "$TMP_DIR"
tar -czvf "$TMP_TAR_NAME" "$ARC_NAME/"*
cd -
mv -f "$TMP_TAR_NAME" "$DEST_FILE"
rm -rf "$ARC_DIR"

aws s3 cp $DEST_FILE s3://$S3_BUCKET/$S3_PATH/$DEST_FILE
echo "$DEST_FILE pushed to s3 - s3://$S3_BUCKET/$S3_PATH/$DEST_FILE"

exit 0
