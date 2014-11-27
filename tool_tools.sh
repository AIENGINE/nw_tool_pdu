#!/bin/bash

function create_node_hash {
	MD5STRING="${TIME_STAMP}${TOOL_VERSION}${TOOL_UNAME}${TOOL_UID}"
	MD5HASH=($(echo -n ${MD5STRING} | md5sum)[0])
	debug "Hash - String: ${MD5STRING}"
	echo "${MD5HASH}"
}
