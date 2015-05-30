#!/bin/bash

# Organisation Details
ORG=GLOCAL

# Number of CV versions to keep (should not be less than LC Env path)
KEEP_CV_VERS=3

# batch log file
LOGDIR=/var/log/sat6-monthly-batch
LOGFILE=$LOGDIR/daily-purge-cv-versions-batch.log

check_log () {
   if [ ! -d "$LOGDIR" ]; then
     mkdir -p $LOGDIR
  fi
}

logmsg () {
  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[purge-cv-versions] $1" >> $LOGFILE
#  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[purge-cv-versions] $1"
}


purge_cv_versions () {
   # Parameters
   ORG_NAME=$1
   CV_NAME=$2

   logmsg "  purge_cv_versions: Processing CV: $CV_NAME.."

   #How Many versions in CV:
   NUM_CV_VERS=`/usr/bin/hammer content-view version list --organization "$ORG_NAME" --content-view "$CV_NAME" \
     | grep "$CV_NAME" | wc -l`

   DEL_CV_COUNT=`expr $NUM_CV_VERS - $KEEP_CV_VERS`

   # get version IDs in order oldest first
   CV_VERS_IDS=`/usr/bin/hammer content-view version list --organization "$ORG_NAME" --content-view "$CV_NAME" \
     | grep "$CV_NAME" \
     | awk 'BEGIN{FS="|"}{print $1}' \
     | tr -d ' ' \
     | sort -V`

   # Need the CV ID for content-view remove-version command later
   CV_ID=`/usr/bin/hammer content-view list --organization "$ORG_NAME" --name "$CV_NAME" \
     | /bin/grep "$CV_NAME" \
     | /bin/awk 'BEGIN{FS="|"}{ print $1 }' \
     | /bin/sed -e 's/^ *//' -e 's/ *$//'`

   logmsg "  CV $CV_NAME has $NUM_CV_VERS versions, KEEP_CV_VERS=$KEEP_CV_VERS, therefore delete $DEL_CV_COUNT oldest versions"

   if [[ $DEL_CV_COUNT -lt 1 ]]; then
       logmsg "  No versions to delete, returning"
       return
   fi

   logmsg "  Deleting oldest $DEL_CV_COUNT versions for CV $CV_NAME.."

   for VERS in $CV_VERS_IDS
   do
      if [[ $DEL_CV_COUNT -gt 0 ]]; then
         logmsg "    deleting CV $CV_NAME version ID $VERS.."
         DEL_CV_COUNT=`expr $DEL_CV_COUNT - 1`
         REMOVE_RET=`/usr/bin/hammer content-view remove-version --organization $ORG_NAME --id $CV_ID --content-view-version-id $VERS`
         logmsg "    hammer API response: '$REMOVE_RET'"
      fi
   done
   logmsg "  purge_cv_versions: done."
}


# Main
logmsg "Started.."

purge_cv_versions $ORG FOO-1-CV
purge_cv_versions $ORG FOO-2-CV

logmsg "Complete."
exit 0

