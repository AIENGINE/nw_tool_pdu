#!/bin/bash

# Tool description:
# This tool starts simpe dhcp server and wait for any request.
# Goal: Check for DHCP capability of PDU and set specific IP-Address for the next tests
# Tool IN :
# - TimeOut
#
# Tool OUT:
# MAC Address
# - Target IP



# ---- Toolspecific parameters
#
# TOOL_UID - the UID from the TestSuite itself
# TOOL_VERSION - version of exactly this Tool, if we change _anything_ here, we have to change also the Version
# TOOL_UNAME - uhmmmm
# XML_FILE - the name of the Jobfile if its ${1} its the first Argument  
# NODE_ID - with this Name, we can identify the Node in progress, when we add the PID ($$) then we make sure that we use only the node prepared by this tool
# -!- xml -!- this is the representation for xmlstarlet ---> http://xmlstar.sourceforge.net/

TOOL_UID=12
TOOL_VERSION="0.01"
TOOL_UNAME=$(uname -a)
NODE_ID="TEST$$"
LEASE_FILE="/tmp/leases.$$"

XMLSTARLET=/usr/bin/xml


# ----/

# /---- get the globals

XML_FILE=${EXECUTOR_XML_FILE}


# ----/

# ---- Helper functions
# we load our "repo"
source "executor_tools.sh"
source "tool_tools.sh"
# ----/





debug "Executing the DHCP-Tool"
debug "we belive in executor: ${EXECUTOR_HASH}"

# /---- we need some executor related vars, so we fetch them

LOCIP=$(get_executor_attribute "Network_Host_IP")
IFACE=$(get_executor_attribute "Network_Interface")
NETBLOCK=$(get_executor_attribute "Network_IP_Block")

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
	debug "TimeOut for this execution: ${TIMEOUT}"

	# ---- start tool, gather informations & interpret the results
	# set my own IP

	IPOUTPUT=$(ifconfig ${IFACE} ${LOCIP} 2>&1)
	EXITCODE=${?}
	debug "IP: ${IPOUT}"
	if [[ ${EXITCODE} -eq 0 ]]; then
		# Set IP for IF finished
		# now run the dnsmasq with specific timeout in the backgorund
		rm -f ${LEASE_FILE}
		debug "run the dhcp server"
		debug "dhcp-range: ${NETBLOCK}"
		DHCPRESULT=$(timeout ${TIMEOUT} dnsmasq --no-hosts --interface ${IFACE} --dhcp-leasefile=${LEASE_FILE} --no-daemon --dhcp-range=${NETBLOCK},1h ) &
		# give some time to establish the server

		sleep 5
		
		debug "create the Filewatch"

		# prepare the Filewatch

		inotifywait --event modify --timeout ${TIMEOUT} ${LEASE_FILE}
		EXITCODE=${?}
		if [[ ${EXITCODE} -eq 0 ]]; then
			debug "leasefile touched, check whats happened"
			TOOL_RESULT="passed"
			TOOL_RESULT_DESCRIPTION="DHCP delivered"
			debug "read IP from ${LEASE_FILE}"
			cat ${LEASE_FILE}
			LEASES_STRING=$(<${LEASE_FILE})
			LEAS=(${LEASES_STRING})
			debug "we have this: as String ${LEASES_STRING} ->  ${LEAS[@]}"
			debug "IP - ${LEAS[2]}"
			debug "MAC - ${LEAS[1]}"
			# we write this Informations to the executor entry
			set_executor_attribute "DUT-IP" "${LEAS[2]}"
			set_executor_attribute "DUT-MAC" "${LEAS[1]}"
		else 
			TOOL_RESULT="failed"
			if [[ ${EXITCODE} -eq 2 ]]; then
				TOOL_RESULT_DESCRIPTION="TimeOut occured"
			else
				TOOL_RESULT_DESCRIPTION="inotify to lease failed Exitcode: ${EXITCODE}"
			fi
		fi
	else
		TOOL_RESULT="failed"
		TOOL_RESULT_DESCRIPTION="couldnt set my local IP"
	fi

	debug "execution finished..."
	OUTPUT="Ifconfig: ${IPOUTPUT} DHCP:${DHCP_RESULT}"
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



