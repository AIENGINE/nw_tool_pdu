#!/bin/bash
#This is bash script for testing
#ip of the device to be tested is defined in py scripts
#This script contains python calling....Python3.1.5 or 3.3.5 (stable) is recommended.


TOOL_UID=15
TOOL_VERSION="0.01"
TOOL_UNAME=$(uname -a)
SNMP_CMD_python="python3.1 snmptask.py"
XML_FILE="jobxmldumy.xml"
NODE_ID="TEST$$"
SNMP_RES_FILE="snmp_result_xml.xml"
SNMP_RESULT_FILE_PID="sse_snmp_result_xml_$$.xml"
XMLSTARLET=xml

source "executor_tools.sh"
source "tool_tools.sh"

${SNMP_CMD_python} #just for command testing
echo "checking exit status$?"
if [[ $? -eq 0 ]] && [[ -e ${SNMP_RES_FILE} ]]; then

	echo "cheching if the script works $a............"
else
	echo "the exit status is not working"
	exit -1
fi	

echo "xmlstarlet tests begins here"

while [ $(xml sel -t -v "count(//Tool/Description[@UID=${TOOL_UID}][not(../${NODE_ID})])" ${XML_FILE}) -gt 0 ]
do
	echo "work it out..."
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
	# ----/
	
	xml ed --inplace -s ${NODE_XPATH} -t elem -n 'Result' -v "" ${XML_FILE}
	RESULT_XPATH="${NODE_XPATH}/Result"
	
	TMP_XML_RES=$(${XMLSTARLET} sel -t -c "/snmpresult" ${SNMP_RES_FILE})
	
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
	
	OUTPUT_XML=$(echo "${TMP_XML_RES[@]}" | xml esc )
	xml ed --inplace -s ${RESULT_XPATH} -t text -n 'Output' -v "${OUTPUT_XML}" \
		${XML_FILE}
	
	echo "the extracted xml was.......$TMP_XML_RES"
		# ---- tool finished -> cleanup 
	# last entry -> execution successful finished
	xml ed --inplace --update "${NODE_XPATH}/BoolExecFinish" -v 'true' ${XML_FILE}
	
	# remove the work-node because we dont need it any more
	xml ed --inplace --delete "(//Tool/*[self::${WORK_NODE}])[1]" ${XML_FILE} 
	

done
xml ed --inplace --rename "//Tool/*[self::${NODE_ID}]" -v "Test" ${XML_FILE}

echo "out of the loop"          
