# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.0](https://github.com/psprings/devops-stack-sample/tree/0.2.0) - 2016-07-18
[Full Changelog](https://github.com/psprings/devops-stack-sample/compare/0.2.0...0.1.0)
### Added
* Added Jenkins configuration files to be used for creating jobs/template jobs in the Jenkins Docker container
  * SonarQube job with parameterized build accepts GIT_URL and other key parameters. Results of sonar-runner are delivered to the SonarQube container. Triggers Maven job.
  * Maven job with parameterized build accepts GIT_URL and other key parameters. Compiled artifact is delivered to Artifactory container.
  * Defaults to automatic Maven installation
* Added `jenkins_api_client` gem to leverage Jenkins API calls to containers for manipulation after Docker build
  * `jenkins_scale.rb` now has additional methods to support
  * Created `remove_jenkins_api_thor_list` to remove unusable `jenkins_api_client` methods from `thor list`
* Added new `thor` functionality via `Thorfile`
  * Generate URLs for all containers: `thor info:all_urls`
  * Generate/fix Jenkins jobs via `.xml` files: `thor up:generate_jobs`
  * Establish a timeout for initial **docker-api** calls, in order to keep `Thorfile` from hanging -- basic details printed to aid in diagnostics
* Added mini SonarQube library for REST API calls
  * Could turn it into a gem if needed
  * Is not being leveraged for this release

### Modified
* Updated `thor` functionality via `Thorfile`
  * Pipeline generate command now prints all urls and attempts job config: `thor up:generate_pipeline`
    * Fixed scaling logic
* Added additional plugins to default Jenkins image via the `plugins.txt` file in order to accomodate artifactory plugin (delivery-pipeline-plugin is still a work in progress, but accomplished via API calls)

TODO:
* Jenkins `delivery-pipeline-plugin` install baked into Docker build
* Break out library from `jenkins_scale.rb`
* Test on Windows
* Add/modify thor commands
* Add unit tests

## [0.1.0](https://github.com/psprings/devops-stack-sample/tree/0.1.0) - 2016-03-21
### Added
* Added `jenkins_scale.rb` for simplified docker interaction, and as a library
  * Wrap docker CLI
  * Create/destroy docker pipeline
* Added `thor` functionality via `Thorfile`
  * Wrap docker CLI
  * Pass parameters for better control
  * Get information about running containers
* Basic documentation

TODO:
* Break out library from `jenkins_scale.rb`
* Test on Windows
* Add/modify thor commands
