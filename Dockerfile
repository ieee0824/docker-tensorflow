FROM ieee0824/docker-vim

RUN git clone https://github.com/tensorflow/tensorflow.git && \
    cd tensorflow && \
    git checkout r0.11

RUN apt-get update && apt-get install -y swig

RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
	rm get-pip.py


# Set up Bazel.

# We need to add a custom PPA to pick up JDK8, since trusty doesn't
# have an openjdk8 backport.  openjdk-r is maintained by a reliable contributor:
# Matthias Klose (https://launchpad.net/~doko).  It will do until
# we either update the base image beyond 14.04 or openjdk-8 is
# finally backported to trusty; see e.g.
#   https://bugs.launchpad.net/trusty-backports/+bug/1368094
RUN echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" >> /etc/apt/sources.list 
RUN echo "deb http://security.debian.org/ jessie/updates main contrib non-free" >> /etc/apt/sources.list
RUN echo "deb http://ftp.us.debian.org/debian/ jessie-updates main contrib non-free" >> /etc/apt/sources.list
RUN echo "deb http://ftp.us.debian.org/debian/ jessie-backports main contrib non-free" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y openjdk-8-jdk
# Running bazel inside a `docker build` command causes trouble, cf:
#   https://github.com/bazelbuild/bazel/issues/134
# The easiest solution is to set up a bazelrc file forcing --batch.
RUN echo "startup --batch" >>/root/.bazelrc
# Similarly, we need to workaround sandboxing issues:
#   https://github.com/bazelbuild/bazel/issues/418
RUN echo "build --spawn_strategy=standalone --genrule_strategy=standalone" \
    >>/root/.bazelrc
ENV BAZELRC /root/.bazelrc
# Install the most recent bazel release.
RUN echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" |  tee /etc/apt/sources.list.d/bazel.list
RUN curl https://bazel.build/bazel-release.pub.gpg |  apt-key add -
RUN apt-get update && apt-get install bazel
RUN apt-get upgrade bazel

RUN pip --no-cache-dir install \
        ipykernel \
        jupyter \
        matplotlib \
        numpy \
        scipy \
        sklearn \
        Pillow \
        && \
		python -m ipykernel.kernelspec
WORKDIR /root

RUN cd tensorflow && ./configure
RUN bazel build -c opt //tensorflow:libtensorflow.so

RUN cp bazel-bin/tensorflow/libtensorflow.so /usr/local/lib

WORKDIR /root
