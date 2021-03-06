# daemon runs in the background
# run something like tail /var/log/kaasud/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/kaasud:/var/lib/kaasud -v $(pwd)/wallet:/home/kaasu --rm -ti kaasu:0.0.1
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG KAASU_BRANCH=master
ENV KAASU_BRANCH=${KAASU_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/acedais/Kaasu.git /src/kaasu && \
    cd /src/kaasu && \
    git checkout $KAASU_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/kaasud /usr/local/bin/kaasud && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/kaasud && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/kaasu && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the kaasud service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/kaasud kaasud && \
    useradd -s /bin/bash -m -d /home/kaasu kaasu && \
    mkdir -p /etc/services.d/kaasud/log && \
    mkdir -p /var/log/kaasud && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/kaasud/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/kaasud/run && \
    echo "cd /var/lib/kaasud" >> /etc/services.d/kaasud/run && \
    echo "export HOME /var/lib/kaasud" >> /etc/services.d/kaasud/run && \
    echo "s6-setuidgid kaasud /usr/local/bin/kaasud" >> /etc/services.d/kaasud/run && \
    chmod +x /etc/services.d/kaasud/run && \
    chown nobody:nogroup /var/log/kaasud && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/kaasud/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/kaasud/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/kaasud" >> /etc/services.d/kaasud/log/run && \
    chmod +x /etc/services.d/kaasud/log/run && \
    echo "/var/lib/kaasud true kaasud 0644 0755" > /etc/fix-attrs.d/kaasud-home && \
    echo "/home/kaasu true kaasu 0644 0755" > /etc/fix-attrs.d/kaasu-home && \
    echo "/var/log/kaasud true nobody 0644 0755" > /etc/fix-attrs.d/kaasud-logs

VOLUME ["/var/lib/kaasud", "/home/kaasu","/var/log/kaasud"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/kaasu export HOME /home/kaasu s6-setuidgid kaasu /bin/bash"]
