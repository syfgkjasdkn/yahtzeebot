REMOTE_HOST = ${SCW_PAR1_IPV4}

# target: help - Display callable targets
help:
	@echo "This makefile assumes you have docker installed ...\n"
	@echo "Available targets:"
	@egrep "^# target:" Makefile

# target: build_release_on_ubuntu - Builds a release for ubuntu 18.04 in docker
build_release_on_ubuntu:
	PLATFORM=ubuntu bin/release build

# target: upload_ubuntu_release - Uploads a release to a remote host
upload_ubuntu_release:
	PLATFORM=ubuntu REMOTE_HOST=${REMOTE_HOST} bin/release upload

# target: restart_remote_app - Restarts the running app on the remote host
restart_remote_app:
	REMOTE_HOST=${REMOTE_HOST} bin/remote restart

# target: deploy - Builds, uploads, and restarts the app
deploy: | build_release_on_ubuntu upload_ubuntu_release

# # target: tests
# tests:
# 	PLATFORM=ubuntu bin/task tests

# # target: dialyzer
# dialyzer:
# 	PLATFORM=ubuntu bin/task dialyzer
