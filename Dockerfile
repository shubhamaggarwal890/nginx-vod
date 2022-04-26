FROM debian
LABEL maintainer="Shubham <shubhamaggarwal890@gmail.com>"
ADD https://nginx.org/download/nginx-1.20.2.tar.gz ./
RUN tar -xvf nginx-1.20.2.tar.gz && rm nginx-1.20.2.tar.gz
RUN apt-get update && apt-get install -y \ 
    build-essential \
    libpcre3 \
    libpcre3-dev \
    zlib1g \
    zlib1g-dev \
    libssl-dev \
    openssl \
    && cd nginx*/ \
    && ./configure --sbin-path=/usr/bin/nginx --conf-path=/usr/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --with-pcre --pid-path=/var/run/nginx.pid --without-http_autoindex_module --with-http_mp4_module --with-http_flv_module --with-http_ssl_module --with-debug \
    && make \
    && make install
COPY nginx-init-script /etc/init.d/nginx
RUN chmod +x /etc/init.d/nginx
RUN update-rc.d -f nginx defaults
RUN mkdir -p /mnt/data
COPY nginx-conf /usr/nginx/nginx.conf
EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]