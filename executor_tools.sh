#!/bin/bash
# Helper Tools for the Executor Box


function debug {
	echo "${1}" 1>&2
}

function set_executor_attribute {
	# set a new attribute to the Executor Node
	# set_executor_attribute [name] [value]
	debug "adding ${1} with value: ${2} to ExecutorNode: ${EXECUTOR_NODE}"
	${XMLSTARLET} ed --inplace -s ${EXECUTOR_NODE} -t attr -n "${1}" -v "${2}" ${EXECUTOR_XML_FILE}
}

function get_executor_attribute {
	ATTR_NODE="${EXECUTOR_NODE}/@${1}"
	debug "read attribute for ${1} (Node: ${ATTR_NODE})"
	OUT=$(${XMLSTARLET} sel -t -v  "${EXECUTOR_NODE}/@${1}" ${EXECUTOR_XML_FILE})
	debug "Value: ${OUT[@]}"
	echo "${OUT[@]}"
}

function exist_executor_attribute {
	ATTR_NODE="${EXECUTOR_NODE}/@${1}"
	debug "read attribute for ${1} (Node: ${ATTR_NODE})"
	OUT=$(${XMLSTARLET} sel -t -v  "count(${EXECUTOR_NODE}/@${1})" ${EXECUTOR_XML_FILE})
	debug "Value: ${OUT[@]}"
	if [[ ${OUT} -gt 0 ]]; then
		echo 1
	else
		echo 0
	fi
}

function get_value {
	debug "get the Value for: ${1}"
        echo $(xml sel -t -m "${WORK_NODE_XPATH}/Variable[@VarName='${1}']" -v "@VarValue"  ${EXECUTOR_XML_FILE})
}

