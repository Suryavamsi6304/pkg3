FROM python:3.9-slim

WORKDIR /app

COPY pkg3.py .

CMD ["python", "pkg3.py"]