# Use a slim Debian image for a smaller final image
FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk-headless python3 wget procps netcat-openbsd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME 
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Set Hadoop version and installation path
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Download and extract Hadoop (using Apache CDN for faster download)
RUN wget --progress=dot:giga https://mirrors.aliyun.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz -O /tmp/hadoop.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    rm /tmp/hadoop.tar.gz && \
    rm -rf ${HADOOP_HOME}/share/doc

# Create a non-root user to run Hadoop processes
RUN useradd -m -u 1000 hadoop && \
    chown -R hadoop:hadoop ${HADOOP_HOME}

# Set up Hadoop configuration directories
RUN mkdir -p /home/hadoop/hdfs/namenode /home/hadoop/hdfs/datanode && \
    chown -R hadoop:hadoop /home/hadoop/hdfs

# Copy Hadoop configuration files
COPY config/* ${HADOOP_HOME}/etc/hadoop/

# Copy the execution scripts into the container
COPY scripts/ /home/hadoop/scripts/

# Make scripts executable
RUN chmod +x /home/hadoop/scripts/*.py && \
    chmod +x /home/hadoop/scripts/entrypoint.sh

# Switch to the non-root user
USER hadoop

# Set the working directory
WORKDIR /home/hadoop

# The command to run when the container starts
CMD ["/home/hadoop/scripts/entrypoint.sh"]