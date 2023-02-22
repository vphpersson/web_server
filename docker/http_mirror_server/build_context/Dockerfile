FROM python:3.11

WORKDIR /usr/src/app
COPY ./* .

RUN pip install --no-cache-dir -r requirements.txt
RUN wget https://publicsuffix.org/list/public_suffix_list.dat

CMD ["python", "http_mirror_server.py", "--public-suffix-list-path", "public_suffix_list.dat"]
