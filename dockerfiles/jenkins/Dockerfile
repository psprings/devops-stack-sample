FROM jenkins
# ENV JAVA_OPTS="-Xmx8192m"
ENV JENKINS_OPTS="--handlerCountStartup=100 --handlerCountMax=300 --logfile=/var/log/jenkins/jenkins.log"
COPY files/plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt
RUN wget http://repo1.maven.org/maven2/org/codehaus/sonar/runner/sonar-runner-dist/2.4/sonar-runner-dist-2.4.zip -O /tmp/sonar-runner.zip
COPY files/jenkins_home/* /var/jenkins_home/
RUN mkdir /var/jenkins_home/job_configs
COPY files/job_configs/* /var/jenkins_home/job_configs/
USER root
# RUN java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar -s http://127.0.0.1:8080 create-job build_compile_maven < /var/jenkins_home/job_configs/build_compile_maven-config.xml
RUN unzip /tmp/sonar-runner.zip -d /tmp
RUN mv /tmp/sonar-runner-2.4 /opt/sonar-runner
RUN wget http://stedolan.github.io/jq/download/linux64/jq -O /usr/bin/jq && chmod +x /usr/bin/jq
COPY files/sonar-runner.properties /opt/sonar-runner/conf/sonar-runner.properties
USER jenkins
RUN export PATH=/opt/ruby:$PATH
