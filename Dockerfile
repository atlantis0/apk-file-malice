FROM ubuntu:xenial

LABEL maintainer "https://github.com/atlantis0"

LABEL malice.plugin.repository = "https://github.com/atlantis0/apk-file-malice.git"
LABEL malice.plugin.category="metadata"
LABEL malice.plugin.mime="*"
LABEL malice.plugin.docker.engine="*"


# FOR JAVA

RUN apt-get update \
    && apt-get -y install openjdk-9-jre \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/java-9-openjdk-amd64
ENV PATH $JAVA_HOME/bin:$PATH

#############################
# END JAVA


# Create a malice user and group first so the IDs get set the same way, even as
# the rest of this may change over time.
RUN groupadd -r malice && useradd -r -g malice malice

ENV GOSU_VERSION 1.10

RUN set -x \
  && apt-get update -qq \
  && apt-get install -y ca-certificates wget \
  && echo "Grab gosu for easy step-down from root..." \
  && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
  && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
  && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
  && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
  && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true \
  && echo "Clean up unnecessary files..." \
  && apt-get purge -y --auto-remove ca-certificates wget \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV SSDEEP 2.14.1
ENV EXIFTOOL 10.65

RUN buildDeps='ca-certificates \
               build-essential \
               openssl \
               unzip \
               curl' \
  && set -x \
  && apt-get update -qq \
  && apt-get install -yq --no-install-recommends $buildDeps libmagic-dev libc6 \
  && mkdir /malware \
  && chown -R malice:malice /malware \
  && echo "Downloading TRiD and Database..." \
  && curl -Ls http://mark0.net/download/trid_linux_64.zip > /tmp/trid_linux_64.zip \
  && curl -Ls http://mark0.net/download/triddefs.zip > /tmp/triddefs.zip \
  && cd /tmp \
  && unzip trid_linux_64.zip \
  && unzip triddefs.zip \
  && chmod +x trid \
  && mv trid /usr/bin/ \
  && mv triddefs.trd /usr/bin/ \
  && echo "Installing ssdeep..." \
  && curl -Ls https://github.com/ssdeep-project/ssdeep/releases/download/release-$SSDEEP/ssdeep-$SSDEEP.tar.gz > \
    /tmp/ssdeep-$SSDEEP.tar.gz \
  && cd /tmp \
  && tar xzf ssdeep-$SSDEEP.tar.gz \
  && cd ssdeep-$SSDEEP \
  && ./configure \
  && make \
  && make install \
  && echo "Installing exiftool..." \
  && curl -Ls https://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-$EXIFTOOL.tar.gz > \
    /tmp/exiftool.tar.gz \
  && cd /tmp \
  && tar xzf exiftool.tar.gz \
  && cd Image-ExifTool-$EXIFTOOL \
  && perl Makefile.PL \
  && make test \
  && make install \
  && echo "Clean up unnecessary files..." \
  && apt-get purge -y --auto-remove $buildDeps \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.gnupg

ENV GOLANG_VERSION 1.9.2
ENV GOLANG_DOWNLOAD_SHA256 de874549d9a8d8d8062be05808509c09a88a248e77ec14eb77453530829ac02b

COPY . /home/sirackh/gopath/src/github.com/atlantis0/apk-file-malice
RUN buildDeps='ca-certificates \
               build-essential \
               mercurial \
               git-core \
               openssl \
               gnupg \
               curl' \
  && set -x \
  && apt-get update -qq \
  && apt-get install -yq --no-install-recommends $buildDeps \
  && echo "Install Go..." \
  && cd /tmp \
  && ARCH="$(dpkg --print-architecture)" \
  && curl -Ls https://storage.googleapis.com/golang/go$GOLANG_VERSION.linux-$ARCH.tar.gz > /tmp/golang.tar.gz \
  && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf /tmp/golang.tar.gz \
  && export PATH=$PATH:/usr/local/go/bin \
  && echo "Building info Go binary..." \
  && cd /home/sirackh/gopath/src/github.com/atlantis0/apk-file-malice \
  && export GOPATH=/go \
  && export GOBIN=$GOPATH/bin \
  && go version \
  && go get \
  && go build -ldflags "-X main.Version=$(cat VERSION) -X main.BuildTime=$(date -u +%Y%m%d)" -o /bin/info \
  && echo "Clean up unnecessary files..." \
  && apt-get clean \
  && apt-get purge -y --auto-remove --allow-remove-essential $buildDeps \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /go /usr/local/go /root/.gnupg

WORKDIR /malware

ENTRYPOINT ["gosu","malice","info"]
CMD ["--help"]
