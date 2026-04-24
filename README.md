# Hadoop WordCount Container

Docker container that connects to an external Hadoop 3.3.6 cluster and:

- Creates/deletes HDFS directories
- Runs a Streaming MapReduce WordCount job via YARN
- Writes word frequency results back to HDFS

## Build

Download `hadoop-3.3.6.tar.gz` from Apache mirrors first, place it in
the project root, then:

```bash
docker build -t hadoop-client-solution .
```

## Configure

Edit `config/core-site.xml` and `config/yarn-site.xml` to point to your
cluster's NameNode and ResourceManager IPs.

## Run

```bash
docker run --rm hadoop-client-solution
```

## License

MIT License
