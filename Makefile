REMOTE_HOST = ${SCW_PAR1_IPV4}

# target: help - Display callable targets
help:
	@echo "This makefile assumes you have docker installed ...\n"
	@echo "Available targets:"
	@egrep "^# target:" Makefile

# target: upload_ubuntu_release - Uploads a release to a remote host
upload_ubuntu_release:
	PLATFORM=ubuntu REMOTE_HOST=${REMOTE_HOST} bin/release upload
