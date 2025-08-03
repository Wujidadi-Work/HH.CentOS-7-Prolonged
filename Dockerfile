FROM --platform=linux/amd64 centos:7

ARG gcc_version=11.5.0
ARG gcc_sha256=5a447f9a2566d15376beece02270decec8b8c1fcb094b93cb335b23497d58117
ARG openssl_version=3.2.2
ARG openssl_sha256=197149c18d9e9f292c43f0400acaba12e5f52cacfe050f3d199277ea738ec2e7
ARG wget_version=1.25.0
ARG wget_sha256=766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784
ARG curl_version=7.76.1
ARG curl_sha256=5f85c4d891ccb14d6c3c701da3010c91c6570c3419391d485d95235253d837d7
ARG cmake_version=4.0.3
ARG cmake_sha256=8d3537b7b7732660ea247398f166be892fe6131d63cc291944b45b91279f3ffb
ARG libxml2_version=2.9.12
ARG libxml2_sha256=c8d6681e38c56f172892c85ddc0852e1fd4b53b4209e7f4ebf17f7e2eae71d92
ARG libzip_version=1.11.4
ARG libzip_sha256=82e9f2f2421f9d7c2466bbc3173cd09595a88ea37db0d559a9d0a2dc60dc722e
ARG oniguruma_version=6.9.10
ARG oniguruma_sha256=2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05
ARG libsodium_version=1.0.20
ARG libsodium_sha256=ebb65ef6ca439333c2bb41a0c1990587288da07f6c7fd07cb3a18cc18d30ce19
ARG libicu_version_d=77-1
ARG libicu_version_u=77_1
ARG libicu_sha256=588e431f77327c39031ffbb8843c0e3bc122c211374485fa87dc5f3faff24061
ARG zlib_version=1.3.1
ARG zlib_sha256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
ARG libpng_version=1.6.50
ARG libpng_sha256=708f4398f996325819936d447f982e0db90b6b8212b7507e7672ea232210949a
ARG libjpeg_version=3.1.1
ARG libjpeg_sha256=aadc97ea91f6ef078b0ae3a62bba69e008d9a7db19b34e4ac973b19b71b4217c
ARG freetype_version=2.13.3
ARG freetype_sha256=5c3a8e78f7b24c20b25b54ee575d6daa40007a5f4eea2845861c3409b3021747
ARG sqlite_year=2025
ARG sqlite_version_p=3500400
ARG sqlite_sha256=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LD_LIBRARY_PATH="/usr/local/lib64"

# Because CentOS 7 is EOL, switch yum repository to vault.centos.org
RUN sed -i 's|mirror.centos.org|vault.centos.org|g' /etc/yum.repos.d/*.repo && \
    sed -i 's|^#.*baseurl=http|baseurl=http|g' /etc/yum.repos.d/*.repo && \
    sed -i 's|^mirrorlist=http|#mirrorlist=http|g' /etc/yum.repos.d/*.repo && \
    yum-config-manager --enable extras

# Install build tools and dependencies
RUN yum install -y http://vault.centos.org/centos/7/extras/x86_64/Packages/epel-release-7-11.noarch.rpm && \
    yum install -y yum-utils file which util-linux bzip2 ca-certificates wget perl-core \
        gcc gcc-c++ binutils make autoconf automake libtool pkgconfig \
        gmp-devel mpfr-devel libmpc-devel \
        flex bison texinfo \
        libxml2-devel mariadb-libs brotli-devel libffi-devel \
        nginx supervisor cronie openssh-clients && \
    yum clean all && rm -rf /var/cache/yum

# GNU Compiler Collection
RUN wget -q -O gcc.tar.gz https://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.gz && \
    echo "${gcc_sha256} gcc.tar.gz" | sha256sum -c || (echo "gcc download failed" && exit 1) && \
    tar -xzf gcc.tar.gz && \
    cd gcc-${gcc_version} && \
    sed -i 's/wget /wget -k /g' contrib/download_prerequisites && \
    ./contrib/download_prerequisites && \
    ./configure --prefix=/usr/local --enable-languages=c,c++ --disable-multilib --disable-bootstrap && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf gcc* && \
    ldconfig
ENV CC="/usr/local/bin/gcc" \
    CXX="/usr/local/bin/g++"

# OpenSSL
RUN wget -q -O openssl.tar.gz https://www.openssl.org/source/openssl-${openssl_version}.tar.gz && \
    echo "${openssl_sha256}  openssl.tar.gz" | sha256sum -c || (echo "openssl download failed" && exit 1) && \
    tar -xzf openssl.tar.gz && \
    cd openssl-${openssl_version} && \
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib && \
    make && make install && \
    cd .. && rm -rf openssl* && \
    echo "/usr/local/openssl/lib64" > /etc/ld.so.conf.d/openssl.conf && \
    ldconfig -v
ENV PATH="/usr/local/openssl/bin:${PATH}" \
    PKG_CONFIG_PATH="/usr/local/openssl/lib64/pkgconfig" \
    LD_LIBRARY_PATH="/usr/local/openssl/lib64:${LD_LIBRARY_PATH}" \
    LDFLAGS="-L/usr/local/openssl/lib64 -L/usr/local/lib64 -L/usr/local/lib -Wl,-rpath=/usr/local/openssl/lib64 -Wl,-rpath=/usr/local/lib64 -Wl,-rpath=/usr/local/lib" \
    CPPFLAGS="-I/usr/local/openssl/include -I/usr/local/include"

# Wget (latest version)
RUN wget -k -q -O wget.tar.gz https://ftp.gnu.org/gnu/wget/wget-${wget_version}.tar.gz && \
    echo "${wget_sha256}  wget.tar.gz" | sha256sum -c || (echo "wget download failed" && exit 1) && \
    tar -xzf wget.tar.gz && \
    cd wget-${wget_version} && \
    ./configure --prefix=/usr/local --with-ssl=openssl --with-openssl=/usr/local/openssl && \
    make && make install && \
    cd .. && rm -rf wget* && \
    ldconfig

# cURL
RUN /usr/local/bin/wget --no-check-certificate -q -O curl.tar.gz https://curl.se/download/curl-${curl_version}.tar.gz && \
    ls -ahl curl.tar.gz && sha256sum curl.tar.gz && \
    echo "${curl_sha256}  curl.tar.gz" | sha256sum -c || (echo "curl download failed" && exit 1) && \
    tar -xzf curl.tar.gz && \
    cd curl-${curl_version} && \
    ./configure --prefix=/usr/local --with-ssl=/usr/local/openssl --with-zlib=/usr/local --disable-static --without-libpsl --without-ssl-srp --disable-srp --enable-shared && \
    make && make install && \
    cd .. && rm -rf curl* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/curl.conf && \
    ldconfig -v
ENV PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig"

# CMake
RUN curl -sL https://github.com/Kitware/CMake/releases/download/v${cmake_version}/cmake-${cmake_version}.tar.gz -o cmake.tar.gz && \
    echo "${cmake_sha256}  cmake.tar.gz" | sha256sum -c || (echo "cmake download failed" && exit 1) && \
    tar -xzf cmake.tar.gz && \
    cd cmake-${cmake_version} && \
    ./bootstrap --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf cmake* && \
    ldconfig

# libxml2 (disable Python module)
RUN curl -skL https://xmlsoft.org/sources/libxml2-${libxml2_version}.tar.gz -o libxml2.tar.gz && \
    echo "${libxml2_sha256}  libxml2.tar.gz" | sha256sum -c || (echo "libxml2 download failed" && exit 1) && \
    tar -xzf libxml2.tar.gz && \
    cd libxml2-${libxml2_version} && \
    ./configure --prefix=/usr/local --with-zlib=/usr --disable-static --without-python && \
    make && make install && \
    cd .. && rm -rf libxml2* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/libxml2.conf && \
    ldconfig

# libzip
RUN curl -skL https://libzip.org/download/libzip-${libzip_version}.tar.gz -o libzip.tar.gz && \
    echo "${libzip_sha256}  libzip.tar.gz" | sha256sum -c || (echo "libzip download failed" && exit 1) && \
    tar -xzf libzip.tar.gz && \
    cd libzip-${libzip_version} && \
    mkdir build && cd build && \
    cmake .. && make && make install && \
    cd ../.. && rm -rf libzip* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/libzip.conf && \
    ldconfig
ENV PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib64/pkgconfig"

# Oniguruma
RUN curl -sL https://github.com/kkos/oniguruma/releases/download/v${oniguruma_version}/onig-${oniguruma_version}.tar.gz -o onig.tar.gz && \
    echo "${oniguruma_sha256}  onig.tar.gz" | sha256sum -c || (echo "oniguruma download failed" && exit 1) && \
    tar -xzf onig.tar.gz && \
    cd onig-${oniguruma_version} && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf onig* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/oniguruma.conf && \
    ldconfig

# libsodium
RUN curl -sL https://download.libsodium.org/libsodium/releases/libsodium-${libsodium_version}.tar.gz -o libsodium.tar.gz && \
    echo "${libsodium_sha256}  libsodium.tar.gz" | sha256sum -c || (echo "libsodium download failed" && exit 1) && \
    tar -xzf libsodium.tar.gz && \
    cd libsodium-${libsodium_version} && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf libsodium* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/libsodium.conf && \
    ldconfig

# libicu
RUN curl -sL https://github.com/unicode-org/icu/releases/download/release-${libicu_version_d}/icu4c-${libicu_version_u}-src.tgz -o icu4c.tgz && \
    echo "${libicu_sha256}  icu4c.tgz" | sha256sum -c || (echo "libicu download failed" && exit 1) && \
    tar -xzf icu4c.tgz && \
    cd icu/source && \
    CXXFLAGS="-std=c++17" ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    cd ../.. && rm -rf icu* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/icu.conf && \
    ldconfig

# zlib
RUN curl -sL https://zlib.net/zlib-${zlib_version}.tar.gz -o zlib.tar.gz && \
    echo "${zlib_sha256}  zlib.tar.gz" | sha256sum -c || (echo "zlib download failed" && exit 1) && \
    tar -xzf zlib.tar.gz && \
    cd zlib-${zlib_version} && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf zlib* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/zlib.conf && \
    ldconfig

# libpng
RUN curl -sL https://downloads.sourceforge.net/project/libpng/libpng16/${libpng_version}/libpng-${libpng_version}.tar.gz -o libpng.tar.gz && \
    echo "${libpng_sha256}  libpng.tar.gz" | sha256sum -c || (echo "libpng download failed" && exit 1) && \
    tar -xzf libpng.tar.gz && \
    cd libpng-${libpng_version} && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf libpng* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/libpng.conf && \
    ldconfig

# libjpeg (using libjpeg-turbo)
RUN curl -sL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${libjpeg_version}/libjpeg-turbo-${libjpeg_version}.tar.gz -o libjpeg.tar.gz && \
    echo "${libjpeg_sha256}  libjpeg.tar.gz" | sha256sum -c || (echo "libjpeg download failed" && exit 1) && \
    tar -xzf libjpeg.tar.gz && \
    cd libjpeg-turbo-${libjpeg_version} && \
    cmake -G"Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/usr/local . && \
    make && make install && \
    cd .. && rm -rf libjpeg* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/libjpeg.conf && \
    ldconfig

# FreeType
RUN curl -sL https://download.savannah.gnu.org/releases/freetype/freetype-${freetype_version}.tar.gz -o freetype.tar.gz && \
    echo "${freetype_sha256}  freetype.tar.gz" | sha256sum -c || (echo "freetype download failed" && exit 1) && \
    tar -xzf freetype.tar.gz && \
    cd freetype-${freetype_version} && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf freetype* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/freetype.conf && \
    ldconfig
ENV ZLIB_CFLAGS="-I/usr/local/include" \
    ZLIB_LIBS="-L/usr/local/lib -lz"

# SQLite
RUN curl -sL https://sqlite.org/${sqlite_year}/sqlite-autoconf-${sqlite_version_p}.tar.gz -o sqlite.tar.gz && \
    echo "${sqlite_sha256}  sqlite.tar.gz" | sha256sum -c || (echo "sqlite download failed" && exit 1) && \
    tar -xzf sqlite.tar.gz && \
    cd sqlite-autoconf-${sqlite_version_p} && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    cd .. && rm -rf sqlite* && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/sqlite.conf && \
    ldconfig
ENV SQLITE_CFLAGS="-I/usr/local/include" \
    SQLITE_LIBS="-L/usr/local/lib -lsqlite3"

CMD ["/bin/bash"]
