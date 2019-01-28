# ReplicantSwiftServer

A command line program to run a Replicant Server.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

What things you need to install the software and how to install them

```
Xcode
```

### Installing

1. Clone the repository.

2. Navigate to the project folder

3. Update the dependencies using Swift Package Manager
```
swift package update
```
4. Generate the Xcode project
```
swift package generate-xcodeproj
```


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


