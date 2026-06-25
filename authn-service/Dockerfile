FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    Flask==3.0.3 \
    Flask-Cors==5.0.1 \
    PyJWT==2.9.0 \
    python-dotenv==1.0.1 \
    requests==2.32.3

COPY authn-service.py ./

EXPOSE 5000

ENV FLASK_APP=authn-service.py \
    FLASK_RUN_HOST=0.0.0.0 \
    FLASK_RUN_PORT=5000

CMD ["flask", "run"]
