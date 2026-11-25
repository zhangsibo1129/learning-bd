FROM flink:1.20

# 运行期依赖：Iceberg Flink Runtime、S3 FileIO、Kafka SQL Connector、PostgreSQL JDBC
COPY lib/*.jar /opt/flink/lib/

WORKDIR /opt/flink
