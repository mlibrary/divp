FROM ruby:2.7.4

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    libtiff-tools exiftool netpbm

RUN gem install bundler -v 2.4.22

WORKDIR /tmp
RUN wget https://kakadusoftware.com/wp-content/uploads/KDU841_Demo_Apps_for_Linux-x86-64_231117.zip
RUN unzip -j -d kakadu KDU841_Demo_Apps_for_Linux-x86-64_231117.zip
RUN mv /tmp/kakadu/*.so /usr/local/lib
RUN mv /tmp/kakadu/kdu* /usr/local/bin
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/kakadu.conf
RUN ldconfig

ENV APP_PATH=/usr/src/app
RUN mkdir -p $APP_PATH
WORKDIR $APP_PATH
COPY Gemfile Gemfile.lock ./
RUN bundle install
