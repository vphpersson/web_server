FROM python:3.11

WORKDIR /usr/src/app
COPY ./* .

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "web_log_collector.py", "--host", "0.0.0.0", "--port", "8081", "--log-directory", "/var/log/web_log_collector"]
