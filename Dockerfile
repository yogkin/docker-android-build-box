FROM ubuntu:18.04

ENV ANDROID_HOME="/opt/android-sdk" \
    ANDROID_NDK="/opt/android-ndk" \
    FLUTTER_HOME="/opt/flutter" \
    JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/"

# Get the latest version from https://developer.android.com/studio/index.html
ENV ANDROID_SDK_TOOLS_VERSION="4333796"

# Get the latest version from https://developer.android.com/ndk/downloads/index.html
ENV ANDROID_NDK_VERSION="r21c"


# Variables must be references after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK/android-ndk-$ANDROID_NDK_VERSION"

ENV PATH="$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/emulator:$ANDROID_SDK_HOME/tools/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK:$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin"

WORKDIR /tmp

# Installing packages
RUN apt-get update && apt-get install -y wget git curl
RUN apt-get update && apt-get install -y wget file
RUN apt-get update && apt-get install -y wget unzip
RUN apt-get update && apt-get install -y wget which
RUN apt-get update && apt-get install -y wget zip
RUN apt-get update && apt-get install -y wget xz-utils
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-8-jdk
RUN apt-get update && apt-get install -y maven ant ruby rbenv make

# Install Android SDK
RUN echo "sdk tools ${ANDROID_SDK_TOOLS_VERSION}" && \
    wget --quiet --output-document=sdk-tools.zip \
        "https://dl.google.com/android/repository/sdk-tools-linux-${ANDROID_SDK_TOOLS_VERSION}.zip" && \
    mkdir --parents "$ANDROID_HOME" && \
    unzip -q sdk-tools.zip -d "$ANDROID_HOME" && \
    rm --force sdk-tools.zip

RUN echo "ndk ${ANDROID_NDK_VERSION}" && \
    wget --quiet --output-document=android-ndk.zip \
    "http://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux-x86_64.zip" && \
    mkdir --parents "$ANDROID_NDK_HOME" && \
    unzip -q android-ndk.zip -d "$ANDROID_NDK" && \
    rm --force android-ndk.zip

# Install SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir --parents "$HOME/.android/" && \
    echo '### User Sources for Android SDK Manager' > \
        "$HOME/.android/repositories.cfg" && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager --licenses > /dev/null

RUN echo "platforms" && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager \
        "platforms;android-30" \
        "platforms;android-29" \
        "platforms;android-28" \
        "platforms;android-27" \
        "platforms;android-26" \
        "platforms;android-25" > /dev/null

RUN echo "platform tools" && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager \
        "platform-tools" > /dev/null

RUN echo "build tools 25-30" && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager \
        "build-tools;30.0.0" \
        "build-tools;29.0.3" "build-tools;29.0.2" \
        "build-tools;28.0.3" "build-tools;28.0.2" \
        "build-tools;27.0.3" "build-tools;27.0.2" "build-tools;27.0.1" \
        "build-tools;26.0.2" "build-tools;26.0.1" "build-tools;26.0.0" \
        "build-tools;25.0.3" "build-tools;25.0.2" \
        "build-tools;25.0.1" "build-tools;25.0.0" > /dev/null

RUN echo "emulator" && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager "emulator" > /dev/null

RUN echo "kotlin" && \
    wget --quiet -O sdk.install.sh "https://get.sdkman.io" && \
    bash -c "bash ./sdk.install.sh > /dev/null && source ~/.sdkman/bin/sdkman-init.sh && sdk install kotlin" && \
    rm -f sdk.install.sh

RUN echo "Flutter sdk" && \
    cd /opt && \
    wget --quiet https://storage.flutter-io.cn/flutter_infra/releases/stable/linux/flutter_linux_1.20.1-stable.tar.xz -O flutter.tar.xz && \
    tar xf flutter.tar.xz && \
    flutter config --no-analytics && \
    rm -f flutter.tar.xz

# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

# Create some jenkins required directory to allow this image run with Jenkins
RUN mkdir -p /var/lib/jenkins/workspace && \
    mkdir -p /home/jenkins && \
    chmod 777 /home/jenkins && \
    chmod 777 /var/lib/jenkins/workspace && \
    chmod 777 $ANDROID_HOME/.android

COPY README.md /README.md

RUN apt-get update && apt-get install -y maven ant ruby rbenv make
RUN echo "1.554.3" > .lts-version-number
RUN wget -q -O - http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key | sudo apt-key add -
RUN echo deb http://pkg.jenkins-ci.org/debian-stable binary/ >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y jenkins
RUN mkdir -p /var/jenkins_home && chown -R jenkins /var/jenkins_home
ADD init.groovy /tmp/WEB-INF/init.groovy
RUN apt-get install -y zip && cd /tmp && zip -g /usr/share/jenkins/jenkins.war WEB-INF/init.groovy
USER jenkins

# VOLUME /var/jenkins_home - bind this in via -v if you want to make this persistent.
ENV JENKINS_HOME /var/jenkins_home

# for main web interface:
EXPOSE 8080 

# will be used by attached slave agents:
EXPOSE 50000 
CMD ["/usr/bin/java",  "-jar",  "/usr/share/jenkins/jenkins.war"]
