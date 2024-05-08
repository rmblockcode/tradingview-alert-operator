#!/usr/bin/env bash

source venv/bin/activate

source .env

uvicorn main:app --port 8001 --reload