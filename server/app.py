from flask import Flask
from flask_cors import CORS
from routes.auth_routes import auth_bp
from config import config
import os

# Set environment variables to override Werkzeug's default limits
os.environ['WERKZEUG_MAX_CONTENT_LENGTH'] = str(100 * 1024 * 1024)  # 100MB


def create_app(config_name=None):
    if config_name is None:
        config_name = os.environ.get("FLASK_ENV", "default")

    app = Flask(__name__)
    app.config.from_object(config[config_name])

    # Set maximum content length for file uploads (100MB to be safe)
    app.config["MAX_CONTENT_LENGTH"] = 100 * 1024 * 1024

    # Additional Flask configs for handling large uploads
    app.config["UPLOAD_EXTENSIONS"] = [".jpg", ".png", ".wav", ".m4a", ".mp3"]
    app.config["UPLOAD_PATH"] = "uploads"  # Initialize extensions
    CORS(app)

    # Register blueprints
    app.register_blueprint(auth_bp)
    
    # Add error handlers
    @app.errorhandler(413)
    def request_entity_too_large(error):
        return {
            "success": False,
            "error": "File too large. Please compress your files and try again.",
            "max_size_mb": app.config["MAX_CONTENT_LENGTH"] // (1024 * 1024)
        }, 413

    return app


if __name__ == "__main__":
    app = create_app()
    
    try:
        # Try to use waitress server which has better handling of large requests
        from waitress import serve
        print(f"Starting Waitress server on {app.config['HOST']}:{app.config['PORT']}")
        serve(
            app, 
            host=app.config["HOST"], 
            port=app.config["PORT"],
            max_request_body_size=100 * 1024 * 1024,  # 100MB
            cleanup_interval=30,
            channel_timeout=300
        )
    except ImportError:
        # Fallback to Flask's development server with patched limits
        print("Waitress not available, using Flask dev server")
        app.run(
            debug=app.config["DEBUG"],
            host=app.config["HOST"],
            port=app.config["PORT"],
            threaded=True,
        )
