FROM ruby:2.1-onbuild
MAINTAINER psprings
RUN useradd -d "/var/jenkins_home" -u 1000 -m -s /bin/bash jenkins
USER jenkins
VOLUME ["/opt/ruby"]
RUN chown -R jenkins:jenkins /opt/ruby/

CMD ["echo", "Ruby container for Jenkins"]
