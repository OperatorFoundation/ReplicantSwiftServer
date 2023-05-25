# ReplicantSwiftServer

A command line program to run a Replicant Server.

### This repository is not currently being maintained. For the Swift version of our Replicant transport please go here: https://github.com/OperatorFoundation/ReplicantSwift

## Running


### Generating a config file for clients with your server public key

You will need to provide the path to a client config template file that you have saved, and the path that you want the new config file to be saved to.

```
.\ReplicantSwiftServer write [path_to_client.conf_template] [destination_path_for_client.conf]
```

### Running the Server

You will need to provide a path to the Replicant server config, as well as a server config that provides the port to listen on.
** Note: If you are using sequences for Replicant, the add and remove sequences should be flipped from what they are in the Replicant client config. 

```
.\ReplicantSwiftServer run <path_to_replicant.conf> <path_to_server.conf>
```


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details


