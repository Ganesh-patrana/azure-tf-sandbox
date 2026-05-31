# 1. Start with a lightweight Python image
FROM python:3.9-slim

# 2. Set the working directory inside the container
WORKDIR /app

# 3. Copy the requirements and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy the actual Amadeus code
COPY app.py .

# 5. Open port 8080
EXPOSE 8080

# 6. Run the application
CMD ["python", "app.py"]