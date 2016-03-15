FROM jenkins
# ENV JAVA_OPTS="-Xmx8192m"
ENV JENKINS_OPTS="--handlerCountStartup=100 --handlerCountMax=300 --logfile=/var/log/jenkins/jenkins.log"
COPY files/plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt
RUN wget http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/2.4/sonar-runner-dist-2.4.zip -O /tmp/sonar-runner.zip
COPY files/jenkins_home/* /var/jenkins_home/
USER root
RUN unzip /tmp/sonar-runner.zip -d /tmp
RUN mv /tmp/sonar-runner-2.4 /opt/sonar-runner
COPY files/sonar-runner.properties /opt/sonar-runner/conf/sonar-runner.properties
USER jenkins
RUN export PATH=/opt/ruby:$PATH
