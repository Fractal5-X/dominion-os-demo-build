FROM ubuntu:22.04
WORKDIR /app
# Install system dependencies and Python
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    gcc \
    gdal-bin \
    libgdal-dev \
    libgeos-dev \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --upgrade pip
# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Copy application
COPY . .
# Create non-root user
RUN useradd --create-home --shell /bin/bash app && chown -R app:app /app
USER app
# Expose port
EXPOSE 5000
# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD curl -f http://localhost:5000/health || exit 1
CMD ["python3", "app.py"]

# Run application
CMD ["python", "app.py"]
