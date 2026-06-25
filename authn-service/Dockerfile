FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    Flask==1.1.2 \
    Flask-Cors==3.0.8 \
    PyJWT==1.7.1 \
    python-dotenv==0.15.0 \
    requests==2.24.0

COPY authn-service.py ./

EXPOSE 5000

ENV FLASK_APP=authn-service.py \
    FLASK_RUN_HOST=0.0.0.0 \
    FLASK_RUN_PORT=5000

CMD ["flask", "run"]
