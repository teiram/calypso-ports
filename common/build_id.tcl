proc generateBuildID_Verilog {} {

	set buildDate [ clock format [ clock seconds ] -format %y%m%d ]
	set buildTime [ clock format [ clock seconds ] -format %H%M%S ]

	set coreDefinitionFileName "core.definition"
	set version {}
	if { ![catch {open $coreDefinitionFileName r} coreDefinitionFile] } {
		fconfigure $coreDefinitionFile -buffering line
		gets $coreDefinitionFile data
		while {$data != ""} {
     		gets $coreDefinitionFile data
     		if { [regexp {VERSION=(.*)} "$data" all version] == 1 } {
     			break
     		}
		}
		close $coreDefinitionFile
	}
	

	# Create a Verilog file for output
	set outputFileName "build_id.v"
	set outputFile [open $outputFileName "w"]

	# Output the Verilog source
	puts $outputFile "`define BUILD_DATE \"$buildDate\""
	puts $outputFile "`define BUILD_TIME \"$buildTime\""
	puts $outputFile "`define BUILD_VERSION \"calypso-$version\""
	close $outputFile

	# Send confirmation message to the Messages window
	post_message "Generated build identification Verilog module: [pwd]/$outputFileName"
	post_message "Date:             $buildDate"
	post_message "Time:             $buildTime"
	post_message "Version:          $version"
}

# Comment out this line to prevent the process from automatically executing when the file is sourced:
generateBuildID_Verilog
