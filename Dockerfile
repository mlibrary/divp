################################################################################
# BASE
################################################################################
FROM ruby:3.4-bookworm AS base

ARG UID=1000
ARG GID=1000

ARG FEED_VERSION=feed_v1.14.1

RUN gem install bundler

WORKDIR /tmp

RUN curl https://apt.lib.umich.edu/mlibrary-archive-keyring.gpg -o /etc/apt/keyrings/mlibrary-archive-keyring.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/mlibrary-archive-keyring.gpg] https://apt.lib.umich.edu bookworm main" > /etc/apt/sources.list.d/mlibrary.list

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  libtiff-tools\ 
  exiftool \
  netpbm\
  grokj2k


RUN groupadd -g ${GID} -o app
RUN useradd -m -d /app -u ${UID} -g ${GID} -o -s /bin/bash app

ENV GEM_HOME=/gems
ENV PATH="$PATH:/gems/bin"
RUN mkdir -p /gems && chown ${UID}:${GID} /gems

ENV APP_PATH=/app
RUN mkdir -p $APP_PATH


# set up bundler 
USER app
RUN gem install bundler

ENV BUNDLE_PATH="/app/vendor/bundle"

WORKDIR $APP_PATH

################################################################################
# HATHIFEED                                                                    #
################################################################################
FROM base AS hathifeed

USER root
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

USER app
WORKDIR $APP_PATH



################################################################################
# DEVELOPMENT                                                                  # 
################################################################################
FROM hathifeed AS development


################################################################################
# TEST                                                                         # 
################################################################################
FROM base AS test

ENV BUNDLE_PATH="/gems"

COPY --chown=${UID}:${GID} Gemfile* /app/
RUN bundle install
