FROM ubuntu:latest
# FROM jenkins:latest
MAINTAINER psprings

ARG host_in
ENV host_in ${host_in:-http://127.0.0.1}
RUN echo "$host_in"

RUN useradd -d "/var/jenkins_home" -u 1000 -m -s /bin/bash jenkins
USER root
RUN mkdir -p /var/log/jenkins; chown -R jenkins:jenkins /var/log/jenkins/

USER jenkins
COPY files/secrets/* /var/jenkins_home/secrets/
COPY files/jenkins_home/* /var/jenkins_home/
RUN for i in /var/jenkins_home/*.xml; do cat $i; sed -i -- 's|HOST_TO_REPLACE|'"${host_in}"'|g' $i; done
USER root
RUN chown -R jenkins:jenkins /var/jenkins_home/
VOLUME ["/var/log/jenkins", "/var/jenkins_home"]
USER jenkins


CMD ["echo", "Data container for Jenkins"]
