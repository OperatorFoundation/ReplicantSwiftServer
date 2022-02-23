git pull origin main

swift package update || exit 1
swift build || exit 2

sudo ./.build/x86_64-unknown-linux-gnu/debug/ReplicantSwiftServer run replicant_server_config.json

exit 0
