FROM perl:5.32.1-threaded

ENV LANG C.UTF-8

WORKDIR /app

RUN cpanm -nq Carton
COPY cpanfile cpanfile.snapshot ./
RUN carton install --deployment
COPY . .

CMD carton exec perl watchers_eye
