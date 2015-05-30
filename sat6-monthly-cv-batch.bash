#!/bin/bash

# sat6-monthly-cv-batch.bash
#
# Run 1st of every month; crontab:  * * 1 * * cmd_to_run


# Variables:

# Organisation Details
ORG_NAME="GLOCAL"
ORG_LABEL="glocal"

# Monthly Content View names
MONTHLY_CV_1=FOO-1-CV   # Odd
MONTHLY_CV_2=FOO-2-CV   # Even

# Prod and Dev Host Collection names
PROD_HC=prod-hosts-hc
DEV_HC=dev-hosts-hc

# Prod and Dev Lifecycle Environment names
PROD_LCENV=PROD
DEV_LCENV=DEV

# batch log file
LOGDIR=/var/log/sat6-monthly-batch
LOGFILE=$LOGDIR/monthly-cv-batch.log

export PYTHONPATH=/usr/local/lib/python2.7/site-packages/

check_log () {
   if [ ! -d "$LOGDIR" ]; then
     mkdir -p $LOGDIR
  fi
}

logmsg () {
  /bin/echo `date +'%Y%m%d-%H:%M:%S'` "[monthly-cv-batch] $1" >> $LOGFILE
}

publish_new_cv_version () {
   # Parameters
   ORG=$1
   CVNAME=$2

   logmsg "Publishing new version for CV: [$CVNAME] for ORG: [$ORG].."

   # Get Content View ID
   logmsg "\_Obtaining Content View ID for CV [$CVNAME].."
   CVID=`/usr/bin/hammer content-view list --organization "$ORG" --name "$CVNAME" \
     | /bin/grep "$CVNAME" \
     | /bin/awk 'BEGIN{FS="|"}{ print $1 }' \
     | /bin/sed -e 's/^ *//' -e 's/ *$//'`

   #Publish new version to Library
   logmsg "\_Publishing new version of Content View [$CVNAME], CVID [$CVID].."
   PUBVER_OUT=`/usr/bin/hammer content-view publish --organization "$ORG" --name "$CVNAME" --id $CVID --async`

   PUBVER_TASK=`echo $PUBVER_OUT | awk '{ print $8 }'`
   logmsg "\__Waiting for Publish Task: [$PUBVER_TASK] to complete.."
   /usr/bin/hammer task progress --id $PUBVER_TASK

}

promote_cv () {
   # Parameters
   ORG=$1
   LCENV=$2
   CVNAME=$3

   logmsg "Promoting CV: [$CVNAME] into LC ENV: [$LCENV] for ORG: [$ORG].."

   # Get Lifecycle Environment ID
   logmsg "\_Obtaining Lifecycle Environment ID for LCE [$LCENV].."
   LCENVID=`/usr/bin/hammer lifecycle-environment list --organization "$ORG" | /bin/awk 'BEGIN{FS="|"}{ print $1,$2 }' | /bin/grep "$LCENV" | /bin/awk '{print $1}' | /bin/sed -e 's/^ *//' -e 's/ *$//'`

   # Get Content View Latest Version
   logmsg "\_Obtaining Latest Content View [$CVNAME] Version.."
   CVVERID=`/usr/bin/hammer content-view info --name "${CVNAME}" --organization "${ORG}" | /bin/grep "ID:" | /usr/bin/tail -1 | tr -d ' ' | cut -f2 -d ':'`

   # Promote the new Content View Version to the Lifecycle Environment
   logmsg "\_Promoting latest Content View [$CVNAME] with Version [$CVVERID] to Lifecycle Environment [$LCENV] with LCE ID [$LCENVID].."
   PUBPRO_OUT=`/usr/bin/hammer content-view version promote --content-view "${CVNAME}" --organization "${ORG}" --lifecycle-environment-id $LCENVID --id $CVVERID --async`

   PUBPRO_TASK=`echo $PUBPRO_OUT | awk '{ print $8 }'`
   logmsg "\__Waiting for Publish Task: [$PUBPRO_TASK] to complete.."
   /usr/bin/hammer task progress --id $PUBPRO_TASK

   logmsg "\_Complete."
}


# Main
check_log

TIME_START=`date +"%s"`
logmsg "Started.."

# Which month is it?  Odd (CV=1) or Even (CV=2)
if [ ! -z "$1" ]; then MONTH=$1 ; else MONTH=`date +'%m'` ; fi
REM=$(( $MONTH % 2 ))
if [ $REM -eq 0 ]
then
   PROD_CV=$MONTHLY_CV_2
   DEV_CV=$MONTHLY_CV_1
else
   PROD_CV=$MONTHLY_CV_1
   DEV_CV=$MONTHLY_CV_2
fi
logmsg "  Month('${MONTH}'): PROD CV to be $PROD_CV, DEV CV to be $DEV_CV"

# main
logmsg "  Actions this month:"
logmsg "   1) promote $PROD_CV to $PROD_LCENV LC Env"
logmsg "   2) move $PROD_HC to $PROD_CV / $PROD_LCENV"
logmsg "   3) create new snapshot version of $DEV_CV and promote to $DEV_LCENV LC Env"
logmsg "   4) move $DEV_HC to $DEV_CV / $DEV_LCENV"
logmsg ""

# 1)
logmsg "  Promoting last month's DEV content view ($PROD_CV) to PROD LC Env ($PROD_LCENV).."
promote_cv $ORG_NAME $PROD_LCENV $PROD_CV

# 2)
logmsg "  Move PROD Host Collection ($PROD_HC) to new PROD CV ($PROD_CV) in PROD LC Env ($PROD_LCENV).."
/usr/local/lib/python2.7/site-packages/Sat6APIUpdateHC.py -o $ORG_LABEL -c $PROD_HC -e $PROD_LCENV -v $PROD_CV >> $LOGFILE

# 3)
logmsg "  Publish a new version of the new DEV CV ($DEV_CV).."
publish_new_cv_version "$ORG_NAME" "$DEV_CV"
logmsg "  Promote the new DEV CV snapshot ($DEV_CV) to DEV LC Env ($DEV_LCENV).."
promote_cv "$ORG_NAME" "$DEV_LCENV" "$DEV_CV"

# 4)
logmsg "  Move DEV Host Collection ($DEV_HC) to new DEV CV ($DEV_CV) in DEV LC Env ($DEV_LCENV).."
/usr/local/lib/python2.7/site-packages/Sat6APIUpdateHC.py -o $ORG_LABEL -c $DEV_HC -e $DEV_LCENV -v $DEV_CV >> $LOGFILE


TIME_COMPLETE=`date +"%s"`
DURATION=`date -u -d "0 $TIME_COMPLETE seconds - $TIME_START seconds" +"%H:%M:%S"`
logmsg "Finished. (Duration: $DURATION)"

exit 0

