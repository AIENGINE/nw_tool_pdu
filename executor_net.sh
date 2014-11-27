#!/bin/bash

# This is the main executor for all the network tests
#
# WHAT?!?
EXECUTOR_NAME="NetExecutor"
EXECUTOR_VERSION="0.1"
EXECUTOR_TIME_STAMP=$(date +%s)
EXECUTOR_HASH_STRING="${EXECUTOR_TIME_STAMP}${EXECUTOR_VERSION}${EXECUTOR_NAME}$$"
EXECUTOR_HASH_X=($(echo -n ${EXECUTOR_HASH_STRING} | md5sum)[0])
EXECUTOR_HASH="${EXECUTOR_HASH_X[0]}"

XMLSTARLET=/usr/bin/xml

# and the "Tools"???

TOOL_DHCPIP="./dhcp_tool.sh"
TOOL_NMAP="./sse_nmap_tool.sh"
TOOL_ARPIP="./arp_tool.sh"
TOOL_CONFIG_SHOW="./config_show.sh"
TOOL_OPENPORTSCAN="./openport_tool.sh"


# Environment options

XML_FILE=${1}

# /---- Checks:
# Check for our XML File
if [[ ! -e ${XML_FILE} ]]
then
	echo "XML-Inputfile: ${XML_FILE} doesnt exist"
	exit -1
fi
# ----/

# /---- Prepare tool execution, we set variables for the tools, some are host specific(!) and then store
# this information inside the EXECUTOR_NODE

EXECUTOR_XML_FILE=${XML_FILE}
EXECUTOR_NETWORK_INTERFACE="eth0"
EXECUTOR_NETWORK_IP_BLOCK="192.168.189.1,192.168.189.254"
EXECUTOR_NETWORK_HOST_IP="192.168.189.129"
# ----/

# /---- Helper Functions 
source "executor_tools.sh"
# ----/

# /---- Create Executor Node:

debug "Create Executor Node"
debug "Hash String: ${EXECUTOR_HASH_STRING}"

${XMLSTARLET} ed --inplace -s "//Jobs" -t elem -n "Executor" -v "${EXECUTOR_HASH}" ${XML_FILE}

#EXECUTOR_NODE="//Jobs/${EXECUTOR_NAME}[text()='${EXECUTOR_HASH}']"
EXECUTOR_NODE="//Jobs/Executor[text()='${EXECUTOR_HASH}']"



# ----/

# /---- add the "Globals" to the EXECUTOR NODE
debug "adding some Globals"
set_executor_attribute "Executor-Name" "${EXECUTOR_NAME}"
set_executor_attribute "Network_Interface" "${EXECUTOR_NETWORK_INTERFACE}"
set_executor_attribute "Network_IP_Block" "${EXECUTOR_NETWORK_IP_BLOCK}"
set_executor_attribute "Network_Host_IP" "${EXECUTOR_NETWORK_HOST_IP}"
# ----/

# /---- prepare tool execution and export important informations
export EXECUTOR_HASH
export EXECUTOR_NODE
export EXECUTOR_XML_FILE
# ----/


# /---- Execute the Tools:

# (0) the configuration show tool
${TOOL_CONFIG_SHOW}
debug "**** Execute the Tests ****"

# (1) obtain IP
# (1.1) DHCP

if [[ $(exist_executor_attribute "DUT-IP") -eq 1 ]]; then 
	debug "we have an IP"
else
	debug "no IP, try DHCP"
	${TOOL_DHCPIP}
fi

# (1.2) ARP
# check if we have an ip

if [[ $(exist_executor_attribute "DUT-IP") -eq 1 ]]; then 
	debug "we have an IP"
else
	debug "no IP, try ARP"
#	for later use, @this moment, if we have the ARP-Tool defined, we have also the MAC
#	debug "but, so we have a MAC?"
#	if [[ $(exist_executor_attribute "DUT-MAC") -eq 1 ]]; then
#		${TOOL_ARPIP}
#	else
#		debug "cant set IP - you have to do this by your own"
#		debug "I must stop here..."
#		exit 1
#	fi
	${TOOL_ARPIP}
	

fi

# (2) Other Checks

# here we _must_ have the IP, so we check again and stop if not

if [[ $(exist_executor_attribute "DUT-IP") -eq 1 ]]; then 
	debug "we have an IP, everything fine"
else
	debug "no IP, we have BIG Problems, stop the script"
	exit -1
fi

# at this point it seems to be bettter to wait some seconds to stabilize the PDU-IF for the next tests

debug "sleep 5s"
sleep 5
debug "...and continue"



# the other tests

# (2.1)
# check open Ports:

debug "Check for open Ports:"
${TOOL_OPENPORTSCAN}

# (2.2)
# the SSE-NMAP-WHATEVER-SCAN

debug "Nmap Test"
${TOOL_NMAP}





# ----/

