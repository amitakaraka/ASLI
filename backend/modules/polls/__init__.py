from flask import Blueprint

polls_bp = Blueprint('polls', __name__, url_prefix='/api/polls')

from . import routes
