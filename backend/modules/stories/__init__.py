from flask import Blueprint

stories_bp = Blueprint('stories', __name__, url_prefix='/api/stories')

from . import routes
