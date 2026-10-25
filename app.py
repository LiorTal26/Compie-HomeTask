"""One Flask application: HTML forms, DynamoDB access, and a DB-backed health check."""

import json
import logging
import os
import re
import time
from datetime import datetime, timezone
from uuid import uuid4

import boto3
import click
from boto3.dynamodb.conditions import Key
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
from flask import Flask, g, jsonify, redirect, render_template, request, url_for


class DynamoDBStore:
    def __init__(self, table_name):
        options = {
            "region_name": os.getenv("AWS_REGION", "il-central-1"),
            "config": Config(connect_timeout=1, read_timeout=2,
                             retries={"total_max_attempts": 2, "mode": "standard"}),
        }
        if os.getenv("CONFIG_SOURCE") == "local":
            options.update(endpoint_url=os.getenv("DYNAMODB_ENDPOINT", "http://localhost:8000"),
                           aws_access_key_id="local", aws_secret_access_key="local")
        self.table = boto3.resource("dynamodb", **options).Table(table_name)

    def list(self, limit=100):
        result = self.table.query(KeyConditionExpression=Key("pk").eq("ITEMS"),
                                  ScanIndexForward=False, ConsistentRead=True, Limit=limit)
        return [{"id": item["sk"], "text": item["text"], "createdAt": item["createdAt"]}
                for item in result.get("Items", [])]

    def add(self, text):
        item_id = str(time.time_ns() // 1_000_000) + "-" + str(uuid4())
        self.table.put_item(Item={"pk": "ITEMS", "sk": item_id, "text": text,
                                 "createdAt": datetime.now(timezone.utc).isoformat()},
                            ConditionExpression="attribute_not_exists(pk)")
        return item_id

    def remove(self, item_id):
        self.table.delete_item(Key={"pk": "ITEMS", "sk": item_id})


def load_config():
    if os.getenv("CONFIG_SOURCE") == "local":
        return {"welcomeMessage": os.getenv("WELCOME_MESSAGE", "A small app. A complete delivery path."),
                "tableName": os.getenv("TABLE_NAME", "compie-local-items")}
    secret_arn = os.environ["APP_CONFIG_SECRET_ARN"]
    client = boto3.client("secretsmanager", region_name=os.getenv("AWS_REGION", "il-central-1"))
    try:
        config = json.loads(client.get_secret_value(SecretId=secret_arn)["SecretString"])
    finally:
        client.close()
    if (not isinstance(config.get("welcomeMessage"), str)
            or len(config["welcomeMessage"]) > 300
            or not isinstance(config.get("tableName"), str)
            or not re.fullmatch(r"[\w.-]{3,255}", config["tableName"])):
        raise ValueError("Invalid application configuration")
    return config


def create_app(store=None, config=None):
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 4096
    app.config["MAX_FORM_PARTS"] = 10
    app.logger.setLevel(logging.INFO)
    config = config if config is not None else load_config()
    store = store if store is not None else DynamoDBStore(config["tableName"])
    version = os.getenv("APP_VERSION", "local")

    def page(items=None, error=None, connected=True, status=200):
        return render_template("index.html", items=items or [], error=error,
                               connected=connected, welcome=config["welcomeMessage"],
                               version=version), status

    @app.before_request
    def start_request():
        g.request_id = str(uuid4())
        g.started = time.monotonic()

    @app.after_request
    def finish_request(response):
        response.headers["X-Request-Id"] = g.request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; img-src 'self' data:; form-action 'self'; "
            "frame-ancestors 'none'; base-uri 'self'")
        response.headers["Cache-Control"] = "no-store"
        app.logger.info(json.dumps({
            "timestamp": datetime.now(timezone.utc).isoformat(), "event": "request",
            "requestId": g.request_id, "method": request.method, "path": request.path,
            "status": response.status_code,
            "durationMs": round((time.monotonic() - g.started) * 1000), "version": version,
        }))
        return response

    @app.get("/")
    def index():
        return page(store.list())

    @app.post("/items")
    def add_item():
        text = request.form.get("text", "").strip()
        if not 1 <= len(text) <= 200:
            return page(store.list(), error="Enter an item between 1 and 200 characters.", status=400)
        store.add(text)
        return redirect(url_for("index"), code=303)

    @app.post("/items/<item_id>/delete")
    def delete_item(item_id):
        if not re.fullmatch(r"\d{13}-[0-9a-f-]{36}", item_id):
            return page(error="Invalid item ID.", status=400)
        store.remove(item_id)
        return redirect(url_for("index"), code=303)

    @app.get("/health")
    def health():
        try:
            store.list(limit=1)
            return jsonify(status="ok", database="ok", version=version)
        except (BotoCoreError, ClientError):
            app.logger.warning(json.dumps({"event": "database_unavailable",
                                           "requestId": g.request_id, "version": version}))
            return jsonify(status="unavailable", database="unavailable", version=version), 503

    @app.errorhandler(BotoCoreError)
    @app.errorhandler(ClientError)
    def database_unavailable(error):
        app.logger.error(json.dumps({"event": "database_unavailable", "error": type(error).__name__,
                                     "requestId": g.request_id, "version": version}))
        return page(error="The database is temporarily unavailable. Please try again.",
                    connected=False, status=503)

    @app.cli.command("init-local-db")
    def init_local_db():
        """Create the disposable local table. AWS tables are always managed by Terraform."""
        if os.getenv("CONFIG_SOURCE") != "local":
            raise click.ClickException("This command is only for DynamoDB Local.")
        client = store.table.meta.client
        for attempt in range(30):
            try:
                client.create_table(
                    TableName=config["tableName"], BillingMode="PAY_PER_REQUEST",
                    AttributeDefinitions=[{"AttributeName": key, "AttributeType": "S"}
                                          for key in ("pk", "sk")],
                    KeySchema=[{"AttributeName": "pk", "KeyType": "HASH"},
                               {"AttributeName": "sk", "KeyType": "RANGE"}])
                break
            except client.exceptions.ResourceInUseException:
                break
            except BotoCoreError:
                if attempt == 29:
                    raise
                time.sleep(1)
        click.echo("DynamoDB Local table is ready.")

    return app


if __name__ == "__main__":
    create_app().run(host="0.0.0.0", port=8080)
