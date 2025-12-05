################################################################################
# BASE
################################################################################
FROM ruby:3.4-bullseye AS base
ARG KAKADU_FILE=KDU841_Demo_Apps_for_Linux-x86-64_231117.zip
ARG FEED_VERSION=feed_v1.14.1

RUN gem install bundler

WORKDIR /tmp
RUN wget https://kakadusoftware.com/wp-content/uploads/$KAKADU_FILE
RUN unzip -j -d kakadu $KAKADU_FILE
RUN mv /tmp/kakadu/*.so /usr/local/lib
RUN mv /tmp/kakadu/kdu* /usr/local/bin
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/kakadu.conf
RUN ldconfig

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    libtiff-tools\ 
    exiftool \
    netpbm

ENV APP_PATH=/usr/src/app
RUN mkdir -p $APP_PATH

################################################################################
# HATHIFEED                                                                    #
################################################################################
FROM base AS hathifeed

WORKDIR /tmp
RUN wget https://github.com/hathitrust/feed/archive/refs/tags/$FEED_VERSION.zip
RUN unzip $FEED_VERSION.zip 
RUN mv /tmp/feed-$FEED_VERSION /usr/local/feed

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    cpanminus \
    libyaml-libyaml-perl \
    liblog-log4perl-perl \
    libdbd-mysql-perl \ 
    openjdk-17-jre-headless

# Install JHOVE
COPY etc/jhove-auto-install.xml /tmp/jhove-auto-install.xml
RUN curl https://hathitrust.github.io/jhove/jhove-xplt-installer-latest.jar -o /tmp/jhove-installer.jar
RUN java -jar /tmp/jhove-installer.jar /tmp/jhove-auto-install.xml

# Install image validator
ENV FEED_HOME=/usr/local/feed
WORKDIR $FEED_HOME 

RUN cpanm --notest -l /extlib \
  https://github.com/hathitrust/metslib.git@v1.0.1 \
  https://github.com/hathitrust/progress_tracker.git@v0.11.1
RUN cpanm --notest -l /extlib --skip-satisfied --installdeps .

ENV VERSION=feed-development
ENV PERL5LIB="/extlib/lib/perl5:$FEED_HOME/lib"
ENV FEED_VALIDATE_SCRIPT=/usr/local/feed/bin/validate_images.pl



################################################################################
# DEVELOPMENT                                                                  # 
################################################################################
FROM hathifeed AS development

WORKDIR $APP_PATH

ENV BUNDLE_PATH="/usr/src/app/vendor/bundle"

################################################################################
# TEST                                                                         # 
################################################################################
FROM base AS test

WORKDIR $APP_PATH

COPY Gemfile* /usr/src/app/
RUN bundle install
