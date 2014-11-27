#!/bin/bash

# Tool description:
# This tool start a simple nmap scan and reports the open ports

# ---- Toolspecific parameters
#
# TOOL_UID - the UID from the TestSuite itself
# TOOL_VERSION - version of exactly this Tool, if we change _anything_ here, we have to change also the Version
# TOOL_UNAME - uhmmmm
# XML_FILE - the name of the Jobfile if its ${1} its the first Argument  
# NODE_ID - with this Name, we can identify the Node in progress, when we add the PID ($$) then we make sure that we use only the node prepared by this tool
# -!- xml -!- this is the representation for xmlstarlet ---> http://xmlstar.sourceforge.net/

# Version
# 0.02 - added "closed" Ports - they seems to exist but detected as "closed"


TOOL_UID=14
TOOL_VERSION="0.02"
TOOL_UNAME=$(uname -a)
XML_FILE=${1}
NODE_ID="TEST$$"
#LEASE_FILE="/tmp/leases.$$"
NMAP_RESULT_FILE="/tmp/nmap_open_ports_xml.$$"

#execution tools
XMLSTARLET=/usr/bin/xml
NMAPEXEC=/usr/bin/nmap



# ----/

# /---- get the globals

XML_FILE=${EXECUTOR_XML_FILE}

# ----/

# ---- Helper functions
# we load our "repo"
source "executor_tools.sh"
source "tool_tools.sh"
# ----/

# /---- we need some executor related vars, so we fetch them

LOCIP=$(get_executor_attribute "Network_Host_IP")
IFACE=$(get_executor_attribute "Network_Interface")
DUT_IP=$(get_executor_attribute "DUT-IP")

debug "Interface to use: ${IFACE}"
# ----/


# check if we have to do anything
# so first we look for the TOOL_UID and how many entrys we have
# every Test we _made_ with this tool(PID!!!!) is marked with the actual NODE_ID ->

debug "check for things to do"

while [ $(xml sel -t -v "count(//Tool/Description[@UID=${TOOL_UID}][not(../${NODE_ID})])" ${XML_FILE}) -gt 0 ]
do
	debug "work it out ..."
	# first of all(!) - mark the node as our "working node"
	WORK_NODE="PID_$$"
 
	xml ed --inplace -s "(//Tool/Description[@UID=${TOOL_UID}][not(../${NODE_ID})])[1]/.." -t elem -n ${WORK_NODE} ${XML_FILE}

	WORK_NODE_XPATH="(//Tool/*[self::${WORK_NODE}])[1]/.."
	# ---- get the Node related Infos and create testnode
	TIME_STAMP=$(date +%s)
	
	# create the TestNode itself
	xml ed --inplace -s ${WORK_NODE_XPATH} -t elem -n ${NODE_ID} ${XML_FILE}
	NODE_XPATH="${WORK_NODE_XPATH}/${NODE_ID}"
	# ----/

	# ---- create execution Flag if something goes wrong
	xml ed --inplace -s ${NODE_XPATH} -t elem -n 'BoolExecFinish' -v 'false' ${XML_FILE}
	# ----/


	# ------------------------
	# ---- Tool execution ----
	# ------------------------

	debug "Lets execute the tool itself..."
	TOOL_RESULT="unspecified"
	
	# ---- get all the vars for the tool ...
	
	TIMEOUT=$(get_value "TimeOut")
	PORTRANGE=$(get_value "PortRange")
	AOPTIONS=$(get_value "AdvancedOptions")
	debug "TimeOut for this execution: ${TIMEOUT}"

	# ---- start tool, gather informations & interpret the results
	# set my own IP

	IPOUTPUT=$(ifconfig ${IFACE} ${LOCIP} 2>&1)
	EXITCODE=${?}
	if [[ ${EXITCODE} -eq 0 ]]; then
		# Set IP for IF finished
		# now run the dnsmasq with specific timeout in the backgorund
	
		debug "Scan Ports: ${PORTRANGE} on ${DUT_IP} with Options: ${AOPTIONS}"
		NMAPRESULT=$(timeout ${TIMEOUT} nmap -p${PORTRANGE} ${AOPTIONS} -oX - ${DUT_IP})
		NMAP_OUTPUT_XML=$(echo "${NMAPRESULT[@]}" | xml esc )

		# store the result temporary

		echo "${NMAPRESULT}" > ${NMAP_RESULT_FILE}


		# extract the open Port List:
		CLOSEDPORTS=$(${XMLSTARLET} sel -O -t -v "/nmaprun/host/ports/port/*[@state='closed']/../@portid" ${NMAP_RESULT_FILE})
		OPENPORTS=$(${XMLSTARLET} sel -O -t -v "/nmaprun/host/ports/port/*[@state='open']/../@portid" ${NMAP_RESULT_FILE})
		OPENFILTEREDPORTS=$(${XMLSTARLET} sel -O -t -v "/nmaprun/host/ports/port/*[@state='open|filtered']/../@portid" ${NMAP_RESULT_FILE})
		debug "Open Ports: ${OPENPORTS}"


	else
		TOOL_RESULT="failed"
		TOOL_RESULT_DESCRIPTION="couldnt set my local IP"
	fi

	debug "execution finished..."
	OUTPUT="Ifconfig: ${IPOUTPUT} NMAP:${NMAP_OUTPUT_XML}"
	# ----/

	# ------------------------
	# ---- fin ---------------
	# ---- Tool execution ----
	# ------------------------





	# ---- write the Testresults to XML
	# write some testheaderinformations
	# generate md5hash for later use
	MD5HASH=$(create_node_hash)
	debug "md5 Hash: ${MD5HASH}" 
	
	xml ed 	--inplace 	-i ${NODE_XPATH} -t attr -n 'timestamp' -v "${TIME_STAMP}" \
		-i ${NODE_XPATH} -t attr -n 'toolversion' -v "${TOOL_VERSION}" \
		-i ${NODE_XPATH} -t attr -n 'uname' -v "${TOOL_UNAME}" \
		-i ${NODE_XPATH} -t attr -n 'Executor-Hash' -v "${EXECUTOR_HASH}" \
		-i ${NODE_XPATH} -t attr -n 'md5hash' -v "${MD5HASH}" \
		${XML_FILE}
	
	
	# create result node
	xml ed --inplace -s ${NODE_XPATH} -t elem -n 'Result' ${XML_FILE}
	RESULT_XPATH="${NODE_XPATH}/Result"
	# reformat output for xml
	OUTPUT_XML=$(echo "${OUTPUT[@]}" | xml esc )
	# store everything in the XML
	xml ed --inplace 	-i ${RESULT_XPATH} -t attr -n 'BoolResult' -v "${TOOL_RESULT}" \
		-i ${RESULT_XPATH} -t attr -n 'Description' -v "${TOOL_RESULT_DESCRIPTION}" \
		-i ${RESULT_XPATH} -t attr -n 'Closed-Ports' -v "${CLOSEDPORTS}" \
		-i ${RESULT_XPATH} -t attr -n 'Open-Ports' -v "${OPENPORTS}" \
		-i ${RESULT_XPATH} -t attr -n 'Open-Filtered-Ports' -v "${OPENFILTEREDPORTS}" \
		-s ${RESULT_XPATH} -t text -n 'Output' -v "${OUTPUT_XML}" \
		${XML_FILE}
	# ----/

	# ---- tool finished -> cleanup 
	# last entry -> execution successful finished
	xml ed --inplace --update "${NODE_XPATH}/BoolExecFinish" -v 'true' ${XML_FILE}
	
	# remove the work-node because we dont need it any more
	xml ed --inplace --delete "(//Tool/*[self::${WORK_NODE}])[1]" ${XML_FILE}
	
	# get next Node
done

# ----/
# rename all Tests

xml ed --inplace --rename "//Tool/*[self::${NODE_ID}]" -v "Test" ${XML_FILE}

# fin



