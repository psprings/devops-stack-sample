# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.1.0]
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
