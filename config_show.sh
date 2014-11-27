#!/bin/bash

# important variables
XMLSTARLET=/usr/bin/xml

source "executor_tools.sh"

echo "---- this ist what we know ----"
echo "The XML to workout: ${EXECUTOR_XML_FILE}"
echo "The executor-node: ${EXECUTOR_NODE}"
echo "and the HASH itself: ${EXECUTOR_HASH}"
echo "read the attributes (the values) for XML"

${XMLSTARLET} sel -s -t -v "${EXECUTOR_NODE}/@*" ${EXECUTOR_XML_FILE}

#get_executor_attribute "Network_Interface"

echo "-------------------------------"

