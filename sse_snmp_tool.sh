TOOL_UID=15
TOOL_VERSION="0.01"
TOOL_UNAME=$(uname -a)
XML_FILE=${1} #jobxmlfile
NODE_ID="TEST$$"
#LEASE_FILE="/tmp/leases.$$"

SNMP_RESULT_FILE="sse_snmp_result_xml.$$"
SNMP_RES_FILE="snmp_result_xml.xml" #to extract the results output snmpAnalysis
SNMP_python="python3.1 snmptask.py"


XMLSTARLET=xml


XML_FILE=${EXECUTOR_XML_FILE}

# ----/

# ---- Helper functions
# we load our "repo"
source "executor_tools.sh"
source "tool_tools.sh"
# ----/

echo "Executing the DHCP-Tool"

# /---- we need some executor related vars, so we fetch them

LOCIP=$(get_executor_attribute "Network_Host_IP")
IFACE=$(get_executor_attribute "Network_Interface")
NETBLOCK=$(get_executor_attribute "Network_IP_Block")
DUT_IP=$(get_executor_attribute "DUT-IP")

debug "Interface to use: ${IFACE}"
# ----/


# check if we have to do anything
# so first we look for the TOOL_UID and how many entrys we have
# every Test we _made_ with this tool(PID!!!!) is marked with the actual NODE_ID ->

debug "check for things to do"

while [ $(xml sel -t -v "count(//Tool/Description[@UID=${TOOL_UID}])" ${XML_FILE}) -gt 0 ]
do
	debug "work it out ..."
	# first of all(!) - mark the node as our "working node"
	WORK_NODE="PID_$$"
 
	xml ed --inplace -s "(//Tool/Description[@UID=${TOOL_UID}][not(../${NODE_ID})])[1]/.." -t elem -n ${WORK_NODE} -v "" ${XML_FILE}
	
	
	WORK_NODE_XPATH="(//Tool/*[self::${WORK_NODE}])[1]/.."
	# ---- get the Node related Infos and create testnode
	TIME_STAMP=$(date +%s)
	
	#create the TestNode itself
	xml ed --inplace -s ${WORK_NODE_XPATH} -t elem -n ${NODE_ID} -v "" ${XML_FILE}
	NODE_XPATH="${WORK_NODE_XPATH}/${NODE_ID}"
	
	# ---- create execution Flag if something goes wrong
	xml ed --inplace -s ${NODE_XPATH} -t elem -n 'BoolExecFinish' -v 'false' ${XML_FILE}


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

	
		debug "Starting SNMP penetration testing.....loading routines........"
		${SNMP_python} #command is started here with the arguemnts
		echo $?
		if [[ $? -eq 0 ]] && [[ -e ${SNMP_RES_FILE} ]]; then 
	            debug "..... calling snmp routines were successful....."
	            TMP_XML_RES=$(${XMLSTARLET} sel -t -c "/snmpresult" ${SNMP_RES_FILE})
	            OUTPUT_XML=$(echo "${TMP_XML_RES[@]}" | xml esc )
	        else
	            debug "......routines could'nt start......."
	            exit -1	    

                fi
                
		echo "${SNMP_RES_FILE}" > ${SNMP_RESULT_FILE}

	else
		TOOL_RESULT="failed"
		TOOL_RESULT_DESCRIPTION="couldnt set my local IP"
	fi

	debug "execution finished..."

	# ------------------------
	# ---- fin ---------------
	# ---- Tool execution ----
	# ------------------------



	# ---- write the Testresults to XML
	# write some testheaderinformations
	# generate md5hash for later use
	MD5HASH=$(create_node_hash) #calling function in tool_tools.sh
	echo "md5 Hash: ${MD5HASH}" 
	
	xml ed 	--inplace 	-i ${NODE_XPATH} -t attr -n 'timestamp' -v "${TIME_STAMP}" \
		-i ${NODE_XPATH} -t attr -n 'toolversion' -v "${TOOL_VERSION}" \
		-i ${NODE_XPATH} -t attr -n 'uname' -v "${TOOL_UNAME}" \
 		-i ${NODE_XPATH} -t attr -n 'Executor-Hash' -v "${EXECUTOR_HASH}" \
		-i ${NODE_XPATH} -t attr -n 'md5hash' -v "${MD5HASH}" \
		${XML_FILE}
	
	
	# create result node
	xml ed --inplace -s ${NODE_XPATH} -t elem -n 'Result' -v "" ${XML_FILE}
	RESULT_XPATH="${NODE_XPATH}/Result"
	# store everything in the XML
	xml ed --inplace -s ${RESULT_XPATH} -t text -n 'Output' -v "${OUTPUT_XML}" \
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


