from flask import Flask
from flask_cors import CORS
from routes.auth_routes import auth_bp
from config import config
import os


def create_app(config_name=None):
    if config_name is None:
        config_name = os.environ.get("FLASK_ENV", "default")

    app = Flask(__name__)
    app.config.from_object(config[config_name])

    # Initialize extensions
    CORS(app)

    # Register blueprints
    app.register_blueprint(auth_bp)

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(debug=app.config["DEBUG"], host=app.config["HOST"], port=app.config["PORT"])
