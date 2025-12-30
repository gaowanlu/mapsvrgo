FROM ubuntu:latest
RUN mkdir -p /mapsvrgo

COPY . /mapsvrgo
WORKDIR /mapsvrgo

RUN apt update
RUN apt install cmake g++ make git -y
RUN apt install protobuf-compiler libprotobuf-dev  -y
RUN apt install libssl-dev -y
RUN apt install -y nodejs npm

WORKDIR /mapsvrgo
RUN git clone https://github.com/mfavant/avant.git avant_dir

WORKDIR /mapsvrgo/
RUN chmod +x ./*.sh
RUN ./copy_mapsvr2avant.sh

WORKDIR /mapsvrgo
RUN node ./generate_lua.js ./protocol/ ./lua/ProtoLua/

WORKDIR /mapsvrgo/avant_dir
RUN rm -rf CMakeCache.txt \
    && cd protocol \
    && make \
    && cd .. \
    && mkdir build \
    && rm -rf ./build/* \
    && cd build \
    && cmake .. \
    && make -j3 \
    && cd .. \
    && cd bin \
    && ls

WORKDIR /mapsvrgo
RUN ./copy_avant_bin.sh

WORKDIR /mapsvrgo/testing
RUN apt install -y nodejs npm
RUN npm install
RUN npm run proto_gen
RUN npm run build

WORKDIR /mapsvrgo/dbsvrgo
RUN apt install -y golang
RUN chmod +x ./build.sh
RUN ./build.sh

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["./avant --mapsvr && tail -f /dev/null"]
