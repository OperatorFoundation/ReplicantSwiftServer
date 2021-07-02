swift package update || exit 1
swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx11.0" || exit 2

sudo ./.build/x86_64-unknown-linux-gnu/debug/ReplicantSwiftServer run replicant_server_config.json server_config.json

exit 0
