FROM alpine:3.4

ADD https://storage.googleapis.com/kubernetes-release/release/v1.5.1/bin/linux/amd64/kubectl /usr/local/bin/ 
RUN chmod +x /usr/local/bin/kubectl

RUN apk add -U bash
ADD ./*.yaml /app/
ADD ./setup.sh /app/
RUN chmod +x /app/setup.sh

ENTRYPOINT ["/app/setup.sh"]