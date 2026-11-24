# Intentional insecure image recipe for the demo gate. The CI image build does not use this file.
FROM python:latest
MAINTAINER demo@example.invalid
USER root
RUN sudo apt-get update && sudo apt-get install -y curl
ADD app.py /app/app.py
EXPOSE 22
CMD python /app/app.py
