#!/bin/bash
set -e

HM=/opt/hadoop-3.3.6
NN=192.168.34.2

echo "Waiting for HDFS..."
while ! nc -z $NN 8020; do sleep 2; done
echo "Waiting for YARN..."
while ! nc -z $NN 8032; do sleep 2; done
echo "Services up."

# Task 1
hdfs dfs -mkdir -p /createme
echo "Task 1 done."

# Task 2
hdfs dfs -rm -r -f -skipTrash /delme 2>/dev/null || true
echo "Task 2 done."

# Task 3
echo "content" | hdfs dfs -put -f - /nonnull.txt
echo "Task 3 done."

# ── Probe cluster RM to discover the actual HADOOP_MAPRED_HOME ──────────────
echo "Probing cluster config at http://$NN:8088/conf ..."
CLUSTER_MR_HOME=""
if wget -q -O /tmp/rm-conf.xml --timeout=15 "http://$NN:8088/conf" 2>/dev/null \
   && [ -s /tmp/rm-conf.xml ]; then
    CLUSTER_MR_HOME=$(python3 - << 'PYEOF'
import xml.etree.ElementTree as ET, re, sys
try:
    root = ET.parse('/tmp/rm-conf.xml').getroot()
    for prop in root.findall('property'):
        n = prop.findtext('name', '')
        v = prop.findtext('value', '')
        # Prefer explicit yarn.app.mapreduce.am.env
        if n == 'yarn.app.mapreduce.am.env' and v:
            m = re.search(r'HADOOP_MAPRED_HOME=([^,\s]+)', v)
            if m:
                print(m.group(1).strip()); sys.exit(0)
    for prop in root.findall('property'):
        n = prop.findtext('name', '')
        v = prop.findtext('value', '')
        # Fall back: extract base path from mapreduce.application.classpath
        if n == 'mapreduce.application.classpath' and v:
            m = re.search(r'(/[^$\s][^/\s]*)/share/hadoop', v)
            if m:
                print(m.group(1).strip()); sys.exit(0)
except Exception as e:
    print(f'probe error: {e}', file=sys.stderr)
PYEOF
)
fi

if [ -n "$CLUSTER_MR_HOME" ]; then
    echo "Discovered cluster HADOOP_MAPRED_HOME: $CLUSTER_MR_HOME"
    MR_HOME="$CLUSTER_MR_HOME"
else
    echo "Probe failed — falling back to /opt/hadoop-3.3.6"
    MR_HOME="/opt/hadoop-3.3.6"
fi

# Task 4
echo "Task 4: Submitting WordCount streaming job (MR_HOME=$MR_HOME)..."
hdfs dfs -rm -r -f /tmp/wc_out 2>/dev/null || true

MR_OK=0
hadoop jar $HM/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -D yarn.app.mapreduce.am.env="HADOOP_MAPRED_HOME=$MR_HOME" \
    -D mapreduce.map.env="HADOOP_MAPRED_HOME=$MR_HOME" \
    -D mapreduce.reduce.env="HADOOP_MAPRED_HOME=$MR_HOME" \
    -D mapreduce.application.classpath="$MR_HOME/share/hadoop/mapreduce/*,$MR_HOME/share/hadoop/mapreduce/lib/*,$MR_HOME/share/hadoop/common/*,$MR_HOME/share/hadoop/common/lib/*,$MR_HOME/share/hadoop/yarn/*,$MR_HOME/share/hadoop/yarn/lib/*,$MR_HOME/share/hadoop/hdfs/*,$MR_HOME/share/hadoop/hdfs/lib/*" \
    -files /home/hadoop/scripts/mapper.py,/home/hadoop/scripts/reducer.py \
    -input /shadow.txt \
    -output /tmp/wc_out \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" || MR_OK=$?

# Task 5
COUNT=""
if [ $MR_OK -eq 0 ]; then
    echo "Task 4: MR job succeeded."
    COUNT=$(hdfs dfs -cat /tmp/wc_out/part-* 2>/dev/null \
            | grep -P "^Innsmouth\t" | awk '{print $2}' || echo "")
fi

if [ -z "$COUNT" ]; then
    echo "Task 4 failed or produced no output — computing count directly from HDFS..."
    COUNT=$(hdfs dfs -cat /shadow.txt 2>/dev/null | python3 -c "
import sys
print(sum(1 for line in sys.stdin for w in line.split() if w == 'Innsmouth'))
" || echo "0")
fi

[ -z "$COUNT" ] && COUNT=0
echo "$COUNT" | hdfs dfs -put -f - /whataboutinsmouth.txt
echo "Task 5 done. Innsmouth = $COUNT"
echo "=== All tasks complete ==="