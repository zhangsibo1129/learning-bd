FROM flink:1.20

# Iceberg 表格式 + Hadoop（HadoopCatalog 需要 Configuration）
COPY docker/flink/lib/iceberg-flink-runtime-1.20-1.9.1.jar /opt/flink/lib/
COPY docker/flink/lib/hadoop-client-api-3.3.6.jar /opt/flink/lib/
COPY docker/flink/lib/hadoop-client-runtime-3.3.6.jar /opt/flink/lib/
COPY docker/flink/lib/commons-logging-1.2.jar /opt/flink/lib/

# warehouse 目录预创建并授权，保证命名卷首次挂载时可写
RUN mkdir -p /warehouse && chown flink:flink /warehouse
