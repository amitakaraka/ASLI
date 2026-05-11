from flask import Blueprint

confessions_bp = Blueprint('confessions', __name__, url_prefix='/api/confessions')

from . import routes
