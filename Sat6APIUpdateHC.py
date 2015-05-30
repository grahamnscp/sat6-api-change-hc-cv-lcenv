#!/usr/bin/env python

import sys, getopt
import json
import requests

import Sat6APIUtils


# Main
def main(argv):

   # Parse Option Arguments
   org = ''
   cv = ''
   hc = ''
   lcenv = ''
   try:
      opts, args = getopt.getopt(argv,"ho:v:c:e:",["cv=","hc="])
   except getopt.GetoptError:
      print 'Error, Invalid options: Usage: test.py -o <Org label> -v <content View> -c <host Collection> -e <Lifecycle Environment>'
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print 'Usage: test.py -o <Org label> -v <content View> -c <host Collection> -e <Lifecycle Environment>'
         sys.exit()
      elif opt in ("-o"):
         org = arg
      elif opt in ("-v", "--cv"):
         cv = arg
      elif opt in ("-c", "--hc"):
         hc = arg
      elif opt in ("-e"):
         lcenv = arg

   print "Param: Org label is: '" + org + "'"
   print "Param: content View is: '" + cv + "'"
   print "Param: host Collection is: '" + hc + "'"
   print "Param: lifecycle Environment is: '" + lcenv + "'"


   # Establish API Connection to Satellite
   sat6conn = Sat6APIUtils.Sat6APIUtils()

   # Obtain IDs
   org_id = sat6conn.getOrganizationIDByName(org)
   lcenv_id = sat6conn.getLVEnvIDbyName(org_id,lcenv)
   cv_id = sat6conn.getCVIDbyName(org_id,cv)

   # Set CV and LC Env for Hosts in HC
   print 
   print "Updating HC (" + hc + ") with CV (" + cv + "), LC Env (" + lcenv + ").."
   retstat =  sat6conn.setHostCollectionContentView(org_id,cv_id,lcenv_id,hc)
   print "Done. (ret status: " + str(retstat) + ")"

   return retstat


# call main
if __name__ == "__main__":
   main(sys.argv[1:])

