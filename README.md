## Requirements
* Ruby 1.9+
  * Additional Gems (specified below)
* docker
* docker-compose

### Tested on
#### MacOS X
* MacOS X 10.10.5
* Docker version 1.10.2, build c3959b1
* Boot2Docker-cli version: v1.8.0, Git commit: 9a26066
* VirtualBox version 5.0.14

#### CentOS 7
* CentOS Linux release 7.2.1511 (Core)
* Docker version 1.10.3, build 20f81dd

## Setup
### Installation
1. Install Ruby 1.9+
  * If you have chefdk installed, this is not needed
  * Otherwise, follow any of the instructions located here: https://www.ruby-lang.org/en/documentation/installation/
* Install bundler Gem (optional)
  * `$ gem install bundler`
  * More information: http://bundler.io/
* Install docker
  * https://docs.docker.com/
  * If you can, install using the **Docker Toolbox**
  * If you are on a corporate machine, you may have issues with security software such as Digital Guardian. In this instance, you may want to look at doing more of a legacy installation using **boot2docker**
    * Mac OS X example:
    ```shell
    $ # If you don't already have VirtualBox installed
    $ brew cask install virtualbox
    ```
    Then
    ```
    $ brew install docker
    $ brew install boot2docker
    ```
* Install docker-compose
  * https://docs.docker.com/compose/install/

### Clone
1. Clone this project and go into the directory
```shell
$ git clone https://github.com/psprings/devops-stack-sample.git
$ cd devops-stack-sample
```

### Gem install
Install gems using **bundle** (shown above) or by manually installing the gems listed below.
#### Bundle
```shell
$ bundle install
```
#### Gem
Bare minimum
```shell
$ gem install docker-api OptionParser
```
Full (to use **thor** commands below)
```shell
$ gem install docker-api OptionParser thor
```
## Interaction
### Via Ruby
If you don't need fine-grain control or just crave simplicity, the `jenkins_scale.rb`
file can be used to setup or destroy the sample pipeline.

**Syntax**
```shell
$ ruby jenkins_scale.rb [# of Jenkins desired]
```
#### Setup stack
```shell
$ ruby jenkins_scale.rb 1
```
#### Destroy stack
```
$ ruby jenkins_scale.rb 0
```

### Via Thor
All of the CLI commands have been wrapped in a Ruby file that acts based on a
single parameter. In order to give more fine grained control over interaction
with the sample pipeline, a `.thor` file has been created which can be used from
the command line by typing `thor`.

#### Basic commands
To retrieve the command options that are available via the `.thor` file, simply
type `thor list` from the command line.
```shell
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
```shell
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
## Try it out
The first time this is run, it will take a bit of time (if you are running this in AWS, you may need to adjust the mtu for the adapter you are using). The first step involves pulling down all of the necessary docker base images and building additional images. Once this is accomplished, subsequent runs will be very fast.

1. Generate the pipeline using the `generate_pipeline` command. This will pull down necessary images, build images, then run the containers.
```shell
$ thor up:generate_pipeline
```
2. With the pipeline now up we can investigate the running containers.
```shell
$ thor info:running_containers
```
3. We will try to figure out the Jenkins URLs based on environment variables,
or assumptions.
```shell
$ thor info:jenkins_urls
```
4. Stop all containers.
```shell
$ thor down:stop_pipeline
```
5. Bring all containers back up
```shell
$ thor up:generate_pipeline
```
6. Add additional Jenkins containers
```shell
$ thor up:scale_jenkins 2
```
7. Get Jenkins URLs
```shell
$ thor info:jenkins_urls
```
8. Scaled Jenkins back down
```shell
$ thor up:scale_jenkins --scale 1 --delete --include
```
9. Destroy the pipeline
```shell
$ thor destroy:destroy_pipeline
```
