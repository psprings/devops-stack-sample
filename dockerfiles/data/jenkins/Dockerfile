FROM ubuntu:latest
MAINTAINER psprings

RUN useradd -d "/var/jenkins_home" -u 1000 -m -s /bin/bash jenkins
RUN mkdir -p /var/log/jenkins; chown -R jenkins:jenkins /var/log/jenkins/

VOLUME ["/var/log/jenkins", "/var/jenkins_home"]
USER jenkins
COPY files/jenkins_home/* /var/jenkins_home/
USER root
RUN chown -R jenkins:jenkins /var/jenkins_home/

CMD ["echo", "Data container for Jenkins"]
