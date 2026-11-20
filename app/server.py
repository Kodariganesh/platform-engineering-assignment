"""Small FastAPI service for the platform engineering assignment."""

import argparse

from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
import uvicorn


app = FastAPI(
    default_response_class=PlainTextResponse,
    openapi_url=None,
    docs_url=None,
    redoc_url=None,
)


@app.get("/")
async def greeting():
    return "Hello from the platform engineering team!\n"


@app.get("/health")
async def health():
    return "OK\n"


def main():
    parser = argparse.ArgumentParser(description="Run the HTTP service.")
    parser.add_argument("--host", default="127.0.0.1", help="Address to listen on.")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on.")
    args = parser.parse_args()

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
