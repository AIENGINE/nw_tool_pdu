#!/bin/bash

# try to get ip with ARP-PING

# ---- Toolspecific parameters
#
# TOOL_UID - the UID from the TestSuite itself
# TOOL_VERSION - version of exactly this Tool, if we change _anything_ here, we have to change also the Version
# TOOL_UNAME - uhmmmm
# XML_FILE - the name of the Jobfile if its ${1} its the first Argument  
# NODE_ID - with this Name, we can identify the Node in progress, when we add the PID ($$) then we make sure that we use only the node prepared by this tool
# -!- xml -!- this is the representation for xmlstarlet ---> http://xmlstar.sourceforge.net/

# Version 0.01 - Base
# Version 0.02 - add Peppercon ARP Mode

TOOL_UID=11
TOOL_VERSION="0.02"
TOOL_UNAME=$(uname -a)
XML_FILE=${1}
NODE_ID="TEST$$"


XML_FILE=${EXECUTOR_XML_FILE}
XMLSTARLET=/usr/bin/xml

echo "ARP-------"

# ----/

# ---- Helper functions
# we load our "repo"
source "executor_tools.sh"
source "tool_tools.sh"
# ----/

debug "execute the ARP-PING set IP Tool"


# check if we have to do anything
# so first we look for the TOOL_UID and how many entrys we have
# every Test we _made_ with this tool(PID!!!!) is marked with the actual NODE_ID ->

while [ $(xml sel -t -v "count(//Tool/Description[@UID=${TOOL_UID}][not(../${NODE_ID})])" ${XML_FILE}) -gt 0 ]
do
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
	xml ed --inplace	-s ${NODE_XPATH} -t elem -n 'BoolExecFinish' -v 'false' ${XML_FILE}
	# ----/


	# ------------------------
	# ---- Tool execution ----
	# ------------------------

	TOOL_RESULT="unspecified"
	
	# ---- get all the vars for the tool ...
	
	LOCIP=$(get_executor_attribute "Network_Host_IP")
	IFACE=$(get_executor_attribute "Network_Interface")
	MACADDR=$(get_value "MACAddr")
	PDUIP=$(get_value "PDUIP")
	PINGSIZE=$(get_value "PingSize")
	PINGCOUNT=$(get_value "PingCount")
	TIMEOUT=$(get_value "TimeOut")


	# set my own IP
	debug "set my own IP"
	IPOUTPUT=$(ifconfig ${IFACE} ${LOCIP} 2>&1)
	EXITCODE=${?}
	# ---- start tool, gather informations & interpret the results

	
	if [[ ${EXITCODE} -eq 0 ]]; then
		
		debug "set ARP for the IP: ${PDUIP} with MAC: ${MACADDR} on IF: ${IFACE}"
		# Set IP for IF finished
		# set the ARP
		ARPOUTPUT=$(arp -s ${PDUIP} ${MACADDR} -i ${IFACE} 2>&1)
		EXITCODE=${?}
		if [[ ${EXITCODE} -eq 0 ]]; then
			# ok, arp seems to be fine
			# now - the "magic" ping
			debug "now PING to do the Magic"
			PINGOUTPUT=$(ping -s ${PINGSIZE} ${PDUIP} -I ${IFACE} -c ${PINGCOUNT} -W ${TIMEOUT} 2>&1)
			EXITCODE=${?}
			if [[ ${EXITCODE} -eq 0 ]]; then
				TOOL_RESULT_DESCRIPTION="PING for PDU successful"
				TOOL_RESULT="passed"
				set_executor_attribute "DUT-IP" "${PDUIP}"
			else
				debug "no, no :( not successful"
				debug "lets try the peppercon trick"
				# we open telnet to port 1, and will get a kickback
				timeout 10 telnet ${PDUIP} 1
				# wait one moment
				sleep 2 
				# if we are right, ping should now work
				debug "now check the IP again"
				PINGOUTPUT=$(ping -s ${PINGSIZE} ${PDUIP} -I ${IFACE} -c ${PINGCOUNT} -W ${TIMEOUT} 2>&1)
				EXITCODE=${?}
				debug "this-> ${PINGOUTPUT}"
				debug "and the Exitcode ${EXITCODE}"
				if [[ ${EXITCODE} -eq 0 ]]; then
					TOOL_RESULT_DESCRIPTION="PING for successful"
					TOOL_RESULT="passed"
					set_executor_attribute "DUT-IP" "${PDUIP}"
				else
					debug "nothing I can do anymore"
					TOOL_RESULT_DESCRIPTION="PING for PDU NOT successful"
					TOOL_RESULT="failed"
				fi
			fi

		else
			TOOL_RESULT_DESCRIPTION="ARP was not successful"
			TOOL_RESULT="failed"
		fi
	else
		TOOL_RESULT="failed"
		TOOL_RESULT_DESCRIPTION="couldnt set my local IP"
	fi


	OUTPUT="IFCONFIG: ${IPOUTPUT} | ARPOUTPUT: ${ARPOUTPUT} | PINGOUTPUT: ${PINGOUTPUT}"
	# ----/

	# ------------------------
	# ---- fin ---------------
	# ---- Tool execution ----
	# ------------------------





	# ---- write the Testresults to XML
	# write some testheaderinformations
	# generate md5hash for later use
	MD5HASH=$(create_node_hash)
	echo "md5 Hash: ${MD5HASH}" 
	
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



