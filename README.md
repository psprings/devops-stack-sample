## Requirements
* Ruby 1.9+
  * Additional Gems (specified below)
* docker

### Tested on
* MacOS X 10.10.5
* Docker version 1.10.2, build c3959b1
* Boot2Docker-cli version: v1.8.0, Git commit: 9a26066
* VirtualBox version 5.0.14

## Interaction
### Via Ruby

### Via Thor
All of the CLI commands have been wrapped in a Ruby file that acts based on a
single parameter. In order to give more fine grained control over interaction
with the sample pipeline, a `.thor` file has been created which can be used from
the command line by typing `thor`.

#### Basic commands
To retrieve the command options that are available via the `.thor` file, simply
type `thor list` from the command line.
```
$ thor list
destroy
-------
thor destroy:destroy_pipeline  # Stop the full DevOps pipeline and delete containers

down
----
thor down:stop_pipeline  # Stop all running containers, give your computer a break

info
----
thor info:containers          # All containers that exist for the DevOps Stack
thor info:jenkins_urls        # Get the URLs for each running Jenkins container
thor info:running_containers  # Currently running containers that exist for the DevOps Stack

up
--
thor up:generate_pipeline SCALE  # Generate full DevOps pipeline with 1 Jenkins
thor up:scale_jenkins SCALE      # Make sure there are n Jenkins up
```
Some of these commands may accept parameters, these can be accessed by typing `thor help [name of command]`. An example can be seen below:
```
$ thor help up:scale_jenkins
Usage:
  thor up:scale_jenkins SCALE

Options:
  -s, [--scale=SCALE]      # Scale Jenkins to n number
  -o, [--stop=STOP]        # Stop any Jenkins containers above scale number
  -d, [--delete=DELETE]    # Stop and delete any Jenkins containers above scale number
  -i, [--include=INCLUDE]  # Include data containers in the deletion

Make sure there are n Jenkins up
```
