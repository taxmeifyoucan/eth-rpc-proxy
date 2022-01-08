FROM debian:latest
RUN apt update && apt --assume-yes install curl
COPY ./push.sh /opt/scripts/push.sh  
ENTRYPOINT [ "opt/scripts/push.sh" ] 
